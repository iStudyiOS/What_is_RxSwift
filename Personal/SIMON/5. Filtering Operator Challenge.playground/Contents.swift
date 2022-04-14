import Foundation
import RxSwift

example(of: "Challenge 1") {
// 1. skipWhile을 사용: 전화번호는 0으로 시작할 수 없습니다.
// 2. filter를 사용: 각각의 전화번호는 한자리의 숫자 (10보다 작은 숫자)여야 합니다.
// 3. take와 toArray를 사용하여, 10개의 숫자만 받도록 하세요. (미국 전화번호처럼)

  let disposeBag = DisposeBag()

  let contacts = [
    "603-555-1212": "Florent",
    "212-555-1212": "Shai",
    "408-555-1212": "Marin",
    "617-555-1212": "Scott"
  ]

  func phoneNumber(from inputs: [Int]) -> String {
    var phone = inputs.map(String.init).joined()

    phone.insert("-", at: phone.index(
      phone.startIndex,
      offsetBy: 3)
    )

    phone.insert("-", at: phone.index(
      phone.startIndex,
      offsetBy: 7)
    )

    return phone
  }

  let input = PublishSubject<Int>()

  // Add your code here
  input
    .skipWhile { number in number == 0 }
    .filter { number in number < 10 }
    .take(10)
    .toArray()
    .subscribe {
        let phone = phoneNumber(from: $0)
        if let contact = contacts[phone] {
          print("Dialing \(contact) (\(phone))...")
          // Dialing Shai (212-555-1212)...
        } else {
          print("Contact not found")
        }
    } onError: { error in
        print("Error", error.localizedDescription)
    }
    .disposed(by: disposeBag)

  // skipWhile 조건에 맞지 않아 스킵
  input.onNext(0)
  // filter 조건에 맞지 않아 스킵
  input.onNext(603)

  input.onNext(2)
  input.onNext(1)

  // Confirm that 7 results in "Contact not found",
  // and then change to 2 and confirm that Shai is found
  // input.onNext(7) -> input.onNext(2)
  input.onNext(2)

  "5551212".forEach {
    if let number = (Int("\($0)")) {
      input.onNext(number)
    }
  }

  input.onNext(9)
}

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
