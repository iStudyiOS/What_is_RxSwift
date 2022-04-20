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

// 1. EONET API에서 이벤트 카테고리를 패칭 준비하여, 패칭 후 첫 번째 화면에 보여주기
// 2. 이벤트를 다운로드하고 각각의 카테고리 개수를 보여주기
// 3. 사용자가 카테고리를 탭했을 때 해당 카테고리의 이벤트 리스트를 보여주기

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  // CHALLENGE 1 - 인디케이터 구성
  var activityIndicator: UIActivityIndicatorView!
  
  // CHALLENGE 2 - 다운로드 바 구성
  let download = DownloadView()
  
  let categories = BehaviorRelay<[EOCategory]>(value: [])
  let disposeBag = DisposeBag()
  @IBOutlet var tableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()

    // CHALLENGE 1 - 인디케이터 활성화
    activityIndicator = UIActivityIndicatorView()
    activityIndicator.color = .black
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    activityIndicator.startAnimating()
    
    // CHALLENGE 2 - 뷰에 추가
    view.addSubview(download)
    view.layoutIfNeeded()
    
    startDownload()
    
    // 1 - 4) startDownload()로 바인딩 된 categories를 통해 view 갱신 
    categories
      .asObservable()
      .subscribe(onNext: { [weak self] _ in
        DispatchQueue.main.async {
          self?.tableView?.reloadData()
        }
      })
      .disposed(by: disposeBag)
  }

  func startDownload() {
    
    // CHALLENGE 2 - 내부 프로퍼티 초기화
    download.progress.progress = 0.0
    download.label.text = "Download: 0%"
    
    // 1 - 3) EONET class 내 프로퍼티를 가져오면서 데이터 패칭 실행 후, categories에 바인딩
    // eoCategories는 모든 카테고리 array를 다운로드 한다.
    // downloadedEvents는 EONET 클래스에 추가한 events 함수를 호출하여 지난 1년간의 이벤트들을 다운로드, 이 때 카테고리도 함께 전달
    // flatMap을 호출하여 받은 카테고리들을 각각의 카테고리에 대해 하나의 이벤트 observable을 방출하는 observable로 변환한다.
    // 그리고 이 모든 observable들을 하나의 이벤트 array로 병합
    let eoCategories = EONET.categories
    let downloadedEvents = eoCategories
      .flatMap { categories in
        return Observable.from(categories.map { category in
          EONET.events(forLast: 360, category: category)
        })
      }
      // 만약 우리가 25개의 카테고리를 가지고 있고, 각각에 대해 API 리퀘스트를 두번만 한다고 해도 50개의 리퀘스트
      // 따라서 API의 최대접속제한값에 닿지 않으려면 동시 송신 요청 수를 제한
      // 한번에 네 가지 리퀘스트만 실행
      .merge(maxConcurrent: 2)
//    let downloadedEvents = EONET.events(forLast: 360)
    
    // combineLatest를 이용해서 downloaded categories와 downloaded events를 병합하고
    // 이벤트를 가지는 업데이트된 카테고리 리스트를 만들어낸다
    // scan은 소스 observable이 방출하는 모든 값을 축적한 값을 방출한다. 여기서의 축적값은 카테고리의 업데이트 목록이다.
    // 따라서 새로운 이벤트 그룹이 도달할 때마다, scan은 카테고리 업데이트를 방출한다.
    // updateCategories observable이 categories variable을 기반하는 한, 테이블뷰는 업데이트 될 것이다
    let updatedCategories = eoCategories.flatMap { categories in
      downloadedEvents.scan(categories) { updated, events in
        return updated.map { category in
          let eventsForCategory = EONET.filteredEvents(events: events,
                                                       forCategory: category)
          if !eventsForCategory.isEmpty {
            var cat = category
            cat.events = cat.events + eventsForCategory
            return cat
          }
          return category
        }
      }
    }
      // CHALLENGE 1 - 업데이트가 완료 후 인디케이터 비활성화
      // CHALLENGE 2 - 다운로드 바 히든
      .do(onCompleted: { [weak self] in
        DispatchQueue.main.async {
          self?.activityIndicator.stopAnimating()
          self?.download.isHidden = true
        }
      })
//    let updatedCategories = Observable
//      .combineLatest(eoCategories, downloadedEvents) {
//        (categories, events) -> [EOCategory] in
//        return categories.map { category in
//          var cat = category
//          cat.events = events.filter {
//            $0.categories.contains(where: { $0.id == category.id })
//          }
//          return cat
//        }
//      }
    
    // CHALLENGE 2 - eoCategories에 담긴 데이터를 바탕으로 scan()을 통하여
    // count를 더해가면서 합산 값을 받음
    // tuple로 구성하여 현재 들어오는 데이터와 전체 합산 값을 활용
    // 다운로드 바 업데이트
    eoCategories.flatMap { categories in
      return updatedCategories.scan(0) { count, _ in
        return count + 1
        }
        .startWith(0)
        .map { ($0, categories.count) }
      }
      .subscribe(onNext: { tuple in
        DispatchQueue.main.async { [weak self] in
          let progress = Float(tuple.0) / Float(tuple.1)
          self?.download.progress.progress = progress
          let percent = Int(progress * 100.0)
          self?.download.label.text = "Download: \(percent)%"
        }
      })
      .disposed(by: disposeBag)

        
    // categories 프로퍼티와 바인딩
    eoCategories
      .concat(updatedCategories)
      .bind(to: categories)
      .disposed(by: disposeBag)
  }
  
  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    let category = categories.value[indexPath.row]
    cell.textLabel?.text = "\(category.name) (\(category.events.count))"
    cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator : .none
    cell.detailTextLabel?.text = category.description
    return cell
  }
  
  // view 전환, 데이터 전달
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = categories.value[indexPath.row]
    tableView.deselectRow(at: indexPath, animated: true)
    
    guard !category.events.isEmpty else { return }
    
    let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
    eventsController.title = category.name
    eventsController.events.accept(category.events)
    navigationController!.pushViewController(eventsController, animated: true)
  }
  
}

