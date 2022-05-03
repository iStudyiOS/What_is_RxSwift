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

class ViewController: UIViewController {
  let bag = DisposeBag()
    
  @IBOutlet private var searchCityName: UITextField!
  @IBOutlet private var tempLabel: UILabel!
  @IBOutlet private var humidityLabel: UILabel!
  @IBOutlet private var iconLabel: UILabel!
  @IBOutlet private var cityNameLabel: UILabel!
  @IBOutlet weak var tempSwitch: UISwitch!
    
  override func viewDidLoad() {
    super.viewDidLoad()
      style()
    
      // observable은 데이터를 수신하고 모든 가입자에게 일련의 데이터가 도착했음을 알린다. 또한 처리할 값을 푸시할 수 있다.
//      // 1
//      searchCityName.rx.text
//          .filter { ($0 ?? "").characters.count > 0 }
//          .flatMapLatest { text in
//              return ApiController.shared.currentWeather(for: text ?? "Error")
//                  .catchErrorJustReturn(ApiController.Weather.empty)
//          }
//      // 2
//          .observeOn(MainScheduler.instance)
//          .subscribe(onNext: {data in
//              self.tempLabel.text = "\(data.temperature)℃"
//              self.iconLabel.text = data.icon
//              self.humidityLabel.text = "\(data.humidity)%"
//              self.cityNameLabel.text = data.cityName
//          })
//          .disposed(by: bag)
      
      let textSearch = searchCityName.rx
        .controlEvent(.editingDidEndOnExit)
        .asObservable()
      
      let temperature = tempSwitch.rx.controlEvent(.valueChanged).asObservable()
      
      let search = Observable
        .merge(textSearch, temperature)
        .map { self.searchCityName.text ?? "" }
        .flatMapLatest { text in
          ApiController.shared
            .currentWeather(for: text)
            .catchErrorJustReturn(.empty)
        }
        .asDriver(onErrorJustReturn: .empty)
      
      search.map { w in
          if self.tempSwitch.isOn {
            return "\(Int(Double(w.temperature) * 1.8 + 32))° F"
          } else {
            return "\(w.temperature)° C"
          }
        }
        .drive(tempLabel.rx.text)
        .disposed(by: bag)
      
      search.map(\.icon)
        .drive(iconLabel.rx.text)
        .disposed(by: bag)
      
      search.map { "\($0.humidity)%" }
        .drive(humidityLabel.rx.text)
        .disposed(by: bag)
      
      search.map(\.cityName)
        .drive(cityNameLabel.rx.text)
        .disposed(by: bag)
      
      
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    Appearance.applyBottomLine(to: searchCityName)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Style

  private func style() {
    view.backgroundColor = UIColor.aztec
    searchCityName.attributedPlaceholder = NSAttributedString(string: "City's Name",
                                                              attributes: [.foregroundColor: UIColor.textGrey])
    searchCityName.textColor = UIColor.ufoGreen
    tempLabel.textColor = UIColor.cream
    humidityLabel.textColor = UIColor.cream
    iconLabel.textColor = UIColor.cream
    cityNameLabel.textColor = UIColor.cream
  }
}
