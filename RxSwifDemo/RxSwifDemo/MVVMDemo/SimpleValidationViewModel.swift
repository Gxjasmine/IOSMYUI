//
//  SimpleValidationViewModel.swift
//  RxSwifDemo
//
//  Created by fuzhongw on 2019/11/15.
//  Copyright © 2019 fuzhongw. All rights reserved.
//

import UIKit
import RxSwift

class SimpleValidationViewModel {
    // 输出
       let usernameValid: Observable<Bool>
       let passwordValid: Observable<Bool>
       let everythingValid: Observable<Bool>

    // 输入 -> 输出
      init(
          username: Observable<String>,
          password: Observable<String>
          ) {

          usernameValid = username
              .map { $0.count >= 10 }
              .share(replay: 1)

          passwordValid = password
              .map { $0.count >= 10 }
              .share(replay: 1)

          everythingValid = Observable.combineLatest(usernameValid, passwordValid) { $0 && $1 }
              .share(replay: 1)

      }
}
