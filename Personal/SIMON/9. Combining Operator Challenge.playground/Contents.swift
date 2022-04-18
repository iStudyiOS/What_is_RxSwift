import RxSwift
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

// Start coding here!
example(of: "Challenge 1") {
  let source = Observable.of(1, 3, 5, 7, 9)
  let observable = source
        .scan(0, accumulator: +)

  let _ = Observable
        .zip(source, observable, resultSelector: { (curr, total) in
            return "\(curr) \(total)"
        })
        .subscribe(onNext: { value in
            print(value)
        })
}

example(of: "Challenge 2") {
  let source = Observable.of(1, 3, 5, 7, 9)
  let observable = source
        // 초기값을 tuple로 구성 (0: 현재 값, 1: 합계)
        .scan((0, 0), accumulator: { (prev, curr) in
            // 이전 순회에서 reduce된 튜플 값의 두번째 값(total)에 현재 더해야하는 source의 현재 값을 더하면서 합산 값 구성
            return (curr, prev.1 + curr)
            
        })
    
  let _ = observable
        .subscribe(onNext: { value in
            print("\(value.0) \(value.1)")
        })
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
