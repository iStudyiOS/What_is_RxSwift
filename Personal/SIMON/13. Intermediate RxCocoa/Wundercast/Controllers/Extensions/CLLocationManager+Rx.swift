/// Copyright (c) 2019 Razeware LLC
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
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import CoreLocation
import RxSwift
import RxCocoa

//다른 모든 확장자는 .rx 네임스페이스 뒤에 있다. CLLocationManager의 extension 목표는 같은 패턴을 따르는 것이다. RxSwift가 제공하는 반응형 프록시를 활용하여 래핑을 통하여 실현 가능.

// CLLocationManager
extension CLLocationManager: HasDelegate {
    public typealias Delegate = CLLocationManagerDelegate
}

class RxCLLocationManagerDelegateProxy: DelegateProxy<CLLocationManager, CLLocationManagerDelegate>, DelegateProxyType, CLLocationManagerDelegate {
    
    public weak private(set) var locationManager: CLLocationManager?
    
    // delegate를 초기화하고, 모든 구현을 등록
    // CLLocationManager 인스턴스에서 연결된 observable로 데이터를 이동시키는데 사용되는 proxy
    // delegate proxy 패턴을 쓰기위해 클래스를 확장
    public init(locationManager: ParentObject) {
      self.locationManager = locationManager
      super.init(parentObject: locationManager,
                 delegateProxy: RxCLLocationManagerDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
      register { RxCLLocationManagerDelegateProxy(locationManager: $0) }
    }
}

// rx 키워드를 통해 CLLocationManager 인스턴스의 method들을 호출이 가능
extension Reactive where Base: CLLocationManager {
     public var delegate: DelegateProxy<CLLocationManager, CLLocationManagerDelegate> {
         return RxCLLocationManagerDelegateProxy.proxy(for: base)
     }

    // Observable을 사용하면 프록시로 사용되는 대리자는 didUpdateLocations의 모든 호출을 듣고 데이터를 가져오고 CLLocations 배열로 캐스팅합니다.
    // methodInvoked(_:)는 지정된 method가 호출될 때마다 next 이벤트를 보내는 observable을 리턴
     var didUpdateLocations: Observable<[CLLocation]> {
         return delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)))
             .map { parameters in
                 return parameters[1] as! [CLLocation]
         }
     }
    
    // 사용자가 권한을 부여했는지 여부를 알려주는 관찰 가능하도록 구성
    // 1. 두 번째 매개 변수는 구체적인 CLAuthorizationStatus 유형이 아닌 숫자이므로 적절하게 캐스팅하고 원시 값으로 CLAuthorizationStatus의 새 인스턴스를 초기화합니다.
    // 2. startWith를 사용하여 향후 변경 사항이 발생하기 전에 소비자가 즉시 현재 상태를 얻을 수 있도록 합니다.
    var authorizationStatus: Observable<CLAuthorizationStatus> {
    delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didChangeAuthorization:)))
        .map { parameters in
          CLAuthorizationStatus(rawValue: parameters[1] as! Int32)!
        }
        .startWith(CLLocationManager.authorizationStatus())
    }
    
    // 1. authorizationStatus를 구독하고 승인된 상태로 변경될 때까지 기다리세요. 소비자가 이미 위치 서비스를 승인한 경우, startWith in authorizationStatus는 구독 시 즉시 알려줍니다.
    // 2. 승인된 상태가 되면, flatMap을 사용하여 이전에 정의한 didUpdateLocations로 전환하고 방출된 위치 배열의 첫 번째 위치를 얻습니다.
    // 3. 단일 위치만 필요하므로, 첫 번째 위치를 얻으면 take(1)을 사용하여 즉시 완료
    // 4. 마지막으로, 방금 만든 관찰 가능한 것을 반환합니다.
    func getCurrentLocation() -> Observable<CLLocation> {
      let location = authorizationStatus
        .filter { $0 == .authorizedWhenInUse || $0 == .authorizedAlways }
        .flatMap { _ in self.didUpdateLocations.compactMap(\.first) }
        .take(1)
        .do(onDispose: { [weak base] in base?.stopUpdatingLocation() })

      base.requestWhenInUseAuthorization()
      base.startUpdatingLocation()
      return location
    }
 }



