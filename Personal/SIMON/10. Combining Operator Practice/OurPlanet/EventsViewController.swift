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

class EventsViewController: UIViewController, UITableViewDataSource {
  // 현재 슬라이더 값을 BehaviorRelay에 바인딩 한다.
  // 슬라이더 값을 가지는 이벤트만 필터한 이벤트 리스트로 결합한다.
  // 테이블 뷰를 필터된 이벤트들로 바인드 한다.
  
  let days = BehaviorRelay<Int>(value: 360)
  let filteredEvents = BehaviorRelay<[EOEvent]>(value: [])
  // 이전의 테이블 뷰에서 didSelect 될 때 데이터 전달
  let events = BehaviorRelay<[EOEvent]>(value: [])
  let disposeBag = DisposeBag()
  
  @IBOutlet var tableView: UITableView!
  @IBOutlet var slider: UISlider!
  @IBOutlet var daysLabel: UILabel!

  override func viewDidLoad() {
    super.viewDidLoad()

    // 전달 받은 데이터를 토대로 갱신 
    events.asObservable()
      .subscribe(onNext: { [weak self] _ in
        self?.tableView.reloadData()
      })
      .disposed(by: disposeBag)
    
    // days와 events를 결합하여 클로저를 통해 설정한 days 만큼 필요한 이벤트를 필터
    Observable.combineLatest(days, events) { days, events -> [EOEvent] in
      let maxInterval = TimeInterval(days * 24 * 3600)
      return events.filter { event in
        if let date = event.date {
          return abs(date.timeIntervalSinceNow) < maxInterval
        }
        return true
      }
    }
    .bind(to: filteredEvents)
    .disposed(by: disposeBag)
    
    // filterEvents를 테이블 뷰에 바인딩
    filteredEvents.asObservable()
      .subscribe(onNext: { [weak self] _ in
        self?.tableView.reloadData()
      })
      .disposed(by: disposeBag)
    
    // days 값을 label 뷰에 바인딩
    days.asObservable()
      .subscribe(onNext: { [weak self] days in
        self?.daysLabel.text = "Last \(days) days"
      })
      .disposed(by: disposeBag)
    
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 60
  }

  @IBAction func sliderAction(slider: UISlider) {
    // days값을 슬라이더에 바인딩
    days.accept(Int(slider.value))
  }

  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return filteredEvents.value.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell") as! EventCell
    let event = filteredEvents.value[indexPath.row]
    cell.configure(event: event)
    return cell
  }
}
