/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import RxSwift
import RxCocoa

// 1. EONET API에서 이벤트 카테고리를 패칭 준비하여, 패칭 후 첫 번째 화면에 보여주기
// 2. 이벤트를 다운로드하고 각각의 카테고리 개수를 보여주기
// 3. 사용자가 카테고리를 탭했을 때 해당 카테고리의 이벤트 리스트를 보여주기


// - 카테고리별로 다운로드를 쪼개보기
// 1. 먼저 카테고리를 받는다.
// 2. 각각의 카테고리에 대해서 이벤트를 리퀘스트한다.
// 3. 새로운 이벤트 블록이 올 때마다 카테고리를 업데이트 하고 테이블뷰를 새로고침한다.
// 4. 모든 카테고리가 이벤트값을 가질 때까지 계속한다.

class EONET {
  static let API = "https://eonet.sci.gsfc.nasa.gov/api/v2.1"
  static let categoriesEndpoint = "/categories"
  static let eventsEndpoint = "/events"

  // 1 - 2) 카테고리 데이터 패칭 & share을 통한 바인딩 작업 전 처리
  static var categories: Observable<[EOCategory]> = {
    // request 메서드를 통해 endpoint에서 데이터 리퀘스트 - 리스폰스에서 categories array 추출
    let request: Observable<[EOCategory]> = EONET.request(endpoint: categoriesEndpoint, contentIdentifier: "categories")
    return request
      // 추출한 것들을 EOCategory array 객체로 매핑하고 이들을 이름별로 정렬
      .map { categories in categories.sorted { $0.name < $1.name } }
      // 만약 네트워크 에러가 발생하면 빈 array 방출
      .catchErrorJustReturn([])
      // singleton으로 Observable<[EOCategory]>를 구성했기에, 모든 subscribe는 같은 스트림을 받아야 한다
      // 첫 번째 subscribe는 요청에 대한 트리거 발생
      // share(replay: 1, scope: .forever)는 모든 요소를 첫 번째 subscribe에게 중계
      // 그런 다음 데이터를 다시 요청하지 않고 마지막으로 수신된 요소를 새 subscribe에게 replay
      // scope: .forever를 통해 캐시처럼 작동.
      .share(replay: 1, scope: .forever)
  }()
  
  static func jsonDecoder(contentIdentifier: String) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[.contentIdentifier] = contentIdentifier
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func filteredEvents(events: [EOEvent], forCategory category: EOCategory) -> [EOEvent] {
    return events.filter { event in
      return event.categories.contains(where: { $0.id == category.id }) && !category.events.contains {
        $0.id == event.id
      }
      }
      .sorted(by: EOEvent.compareDates)
  }
  
  // 1 - 1) EONET API에 데이터 리퀘스트 구성
  static func request<T: Decodable>(endpoint: String, query: [String: Any] = [:], contentIdentifier: String) -> Observable<T> {
    // URL 구성, 실패 시 Error throw
    do {
      guard let url = URL(string: API)?.appendingPathComponent(endpoint), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { throw EOError.invalidURL(endpoint) }
      // Query string 구성
      components.queryItems = try query.compactMap{ (key, value) in
        guard let v = value as? CustomStringConvertible else { throw EOError.invalidParameter(key, value) }
        return URLQueryItem(name: key, value: v.description)
      }
      // URLComponents를 통한 URL 구성
      guard let finalURL = components.url else {
        throw EOError.invalidURL(endpoint)
      }
      // 요청 객체 생성
      let request = URLRequest(url: finalURL)
      
      // URLSession의 rx.response는 리퀘스트 결과를 통해 observable을 생성한다. 데이터를 받으면 이를 객체로 decode
      return URLSession.shared.rx.response(request: request)
        .map { (result: (response: HTTPURLResponse, data: Data)) -> T in
          let decoder = self.jsonDecoder(contentIdentifier: contentIdentifier)
          let envelope = try decoder.decode(EOEnvelope<T>.self, from: result.data)
          return envelope.content
        }
      // try-do-catch 구문을 완성한다. 에러 처리
    } catch {
      return Observable.empty()
    }
  }
  
  // 2 - 1) 이벤트 다운로드 서비스 추가
  // EONET API는 이벤트 다운로드를 할 수 있는 두 개의 endpoint(all events: open, events per category: closed)를 제공
  // Open 이벤트는 진행중인 놈들이다. Closed 이벤트는 종료되어 과거에 있는 녀석
  private static func events(forLast days: Int, closed: Bool, endpoint: String) -> Observable<[EOEvent]> {
    // 이벤트 검색을 위해 되돌아볼 일수, 이벤트의 open 또는 closed 상태
    let query: [String: Any] = [
      "days": days,
      "status": (closed ? "closed" : "open")
    ]
    let request: Observable<[EOEvent]> = EONET.request(endpoint: endpoint, query: query, contentIdentifier: "events")
    return request.catchErrorJustReturn([])
  }
  
  // API는 open 또는 closed 이벤트를 별도로 다운로드 하도록 권고
  // 하나의 흐름을 통해 구독 - 리퀘스트를 두 번 보낸 뒤 각각의 결과를 연결(concat)
  // 병렬적으로 진행 가능하도록 merge()를 통한 개선
  // 먼저 카테고리를 받는다. 각각의 카테고리에 대해서 이벤트를 리퀘스트한다.
  static func events(forLast days: Int = 360, category: EOCategory) -> Observable<[EOEvent]> {
    let openEvents = events(forLast: days, closed: false, endpoint: category.endpoint)
    let closedEvents = events(forLast: days, closed: true, endpoint: category.endpoint)
    return Observable.of(openEvents, closedEvents)
      .merge()
      .reduce([]) { running, new in
        running + new
      }
  }
}


