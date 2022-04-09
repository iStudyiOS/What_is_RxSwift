//
//  UIViewController+Extension.swift
//  Combinestagram
//
//  Created by Sang hun Lee on 2022/04/09.
//  Copyright © 2022 Underplot ltd. All rights reserved.
//

import Foundation
import UIKit
import RxSwift

extension UIViewController {
  func alert(title: String, text: String?) -> Completable {
        return Completable.create(subscribe: { [weak self] completable in
            let alertVC = UIAlertController(title: title, message: text, preferredStyle: .alert)
            let closeAction = UIAlertAction(title: "Close", style: .default, handler: { _ in
                completable(.completed)
            })
            alertVC.addAction(closeAction)
            self?.present(alertVC, animated: true, completion: nil)
            return Disposables.create {
                self?.dismiss(animated: true, completion: nil)
            }
        })
    }
}
