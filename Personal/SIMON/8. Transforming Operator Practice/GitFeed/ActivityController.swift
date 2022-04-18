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

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

class ActivityController: UITableViewController {
  private let repo = "ReactiveX/RxSwift"
  private let eventsFileURL = cachedFileURL("events.json")
  private let modifiedFileURL = cachedFileURL("modified.txt")
  private let events = BehaviorRelay<[Event]>(value: [])
  private let lastModified = BehaviorRelay<String?>(value: nil)
  private let bag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = repo

    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!

    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)

    // 초기 실행 시 외부 파일에 있는 데이터를 불러오고 이를 디코딩하여 초기 이벤트에 넣어주기
    let decoder = JSONDecoder()
    if let eventsData = try? Data(contentsOf: eventsFileURL),
      let persistedEvents = try? decoder.decode([Event].self, from:
    eventsData) {
      events.accept(persistedEvents)
    }
    
    // 이전에 Last-Modified 헤더의 값을 파일에 저장했다면 문자열을 생성하고
    // lastModified에 전달
    if let lastModifiedString = try? String(contentsOf: modifiedFileURL,
    encoding: .utf8) {
      lastModified.accept(lastModifiedString)
    }
    
    refresh()
  }

  @objc func refresh() {
    DispatchQueue.global(qos: .default).async { [weak self] in
      guard let self = self else { return }
      self.fetchEvents(repo: self.repo)
    }
  }

  func fetchEvents(repo: String) {
    let response = Observable
      .from([repo])
      // → Observable<URL>
      .map { urlString -> URL in
        return URL(string: "https://api.github.com/repos/\(urlString)/events")!
      }
      // → Observable<URLRequest>
      // 저장된 헤더 값을 사용하여 요청하면서
      // 추가 헤더는 GitHub API에 헤더 날짜보다 오래된 이벤트에 관심이 없다는 것을 알려줌
      .map { [weak self] url -> URLRequest in
          var request = URLRequest(url: url)
          if let modifiedHeader = self?.lastModified.value {
              request.addValue(modifiedHeader as String, forHTTPHeaderField: "Last-Modified")
          }
          return request
      }
      // 1. 일반적인 map으로 했다면 Observable<Observable<(response: HTTPURLResponse, data: Data)>>
      // flatMap을 통해서 평탄화: → Observable<(response: HTTPURLResponse, data: Data)>
      // 2. 비동기 작업을 수행하는 Observable을 평탄화하고 Observable의 완료를 효과적으로 "대기"한 다음 체인의 나머지 부분을 계속 작동시킬 수 있다.
      // 상기 코드에서 flatMap은 웹 리퀘스트를 보내게 해주고 프로토콜이나 델리게이트 없이도 리스폰스를 받을 수 있게 해준다.
      // 간단하게 map과 flatMap 연산자의 조합을 통해 비동기적인 일련의 코드 작성이 가능
      .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
           // RxCocoa response(request:)을 통해서 앱이 웹 서버를 통해 full response를 받을 때마다
           // complete되는 Observable<(response: HTTPURLResponse, data: Data)>를 반환
           return URLSession.shared.rx.response(request: request)
       }
      .share(replay: 1, scope: .whileConnected)
    
    response
      // HTTP response에서 success한 응답만 캐치
      .filter { response, _ in
        return 200..<300 ~= response.statusCode
      }
      // Corderable을 통한 Json Data 변환
      .map { _, data -> [Event] in
        let decoder = JSONDecoder()
        let events = try? decoder.decode([Event].self, from: data)
        return events ?? []
      }
      // 빈 데이터 검사
      .filter { objects in
        return !objects.isEmpty
      }
      .subscribe(onNext: { [weak self] newEvents in
        self?.processEvents(newEvents)
      })
      .disposed(by: bag)
    
    // 이전에 받지 않은 이벤트만 요청하도록 GitFeed를 최적화
    response
      // 에러 필터링
      .filter { response, _ in
        return 200..<400 ~= response.statusCode
      }
      // Last-Modified header가 없는 response들을 필터
      .flatMap { response, _ -> Observable<String> in
        guard let value = response.allHeaderFields["Last-Modified"] as? String else {
          return Observable.empty()
        }
        return Observable.just(value)
      }
      // 헤더 값을 가지고 와서 그 값 기반으로 업데이트 진행
      // lastModified 속성을 변경하고 값을 디스크에 저장
      .subscribe(onNext: { [weak self] modifiedHeader in
        guard let self = self else { return }
        self.lastModified.accept(modifiedHeader)
        try? modifiedHeader.write(to: self.modifiedFileURL, atomically: true,
      encoding: .utf8)
      })
      .disposed(by: bag)
  }
  
  // side effect 구성
  func processEvents(_ newEvents: [Event]) {
    var updateEvents = newEvents + events.value
    if updateEvents.count > 50 {
      updateEvents = Array<Event>(updateEvents.prefix(upTo: 50))
    }
    
    events.accept(updateEvents)
    
    DispatchQueue.main.async {
      self.tableView.reloadData()
      self.refreshControl?.endRefreshing()
    }
    
    // refresh() 하면서 불러온 데이터를 JSON으로 인코딩하여 외부 파일에 쓰기
    let encoder = JSONEncoder()
    if let eventsData = try? encoder.encode(updateEvents) {
      try? eventsData.write(to: eventsFileURL, options: .atomicWrite)
    }
  }

  // MARK: - Table Data Source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.actor.name
    cell.detailTextLabel?.text = event.repo.name + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.actor.avatar, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
}

// 외부 파일로 caching, realm을 사용한 내부 데이터 활용과 유사
func cachedFileURL(_ fileName: String) -> URL {
  return FileManager.default
    .urls(for: .cachesDirectory, in: .allDomainsMask)
    .first!
    .appendingPathComponent(fileName)
}
