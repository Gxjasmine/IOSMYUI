//
//  MVCViewController.swift
//  RxSwifDemo
//
//  Created by fuzhongw on 2019/11/15.
//  Copyright © 2019 fuzhongw. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class MVCViewController: UIViewController {

    @IBOutlet weak var usernameOutlet: UITextField!

    @IBOutlet weak var error1: UILabel!

    @IBOutlet weak var passwordOutlet: UITextField!

    @IBOutlet weak var error2: UILabel!

    @IBOutlet weak var doSomethingOutlet: UIButton!

    let disposeBag = DisposeBag()

    private var viewModel: SimpleValidationViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        initMyObserve()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}


//MVC 重构前：
extension MVCViewController {

    func initMyObserve()  {

        let usernameValid = usernameOutlet.rx.text.orEmpty
        .map { $0.count >= 10 }
        .share(replay: 1)

        let passwordVaild = passwordOutlet.rx.text.orEmpty
            .map { $0.count >= 10}
        .share(replay: 1)

        let everythingValid = Observable.combineLatest(usernameValid, passwordVaild)
        {$0 && $1}
            .share(replay: 1)

        usernameValid
            .bind(to: passwordOutlet.rx.isEnabled)
            .disposed(by: disposeBag)

        usernameValid
            .bind(to: usernameOutlet.rx.isHidden)
            .disposed(by: disposeBag)

        passwordVaild
            .bind(to: passwordOutlet.rx.isHidden)
            .disposed(by: disposeBag)

        everythingValid
            .bind(to: doSomethingOutlet.rx.isEnabled)
            .disposed(by: disposeBag)

        doSomethingOutlet.rx.tap
            .subscribe(onNext: { [weak self] in
                print("弹框提示")
            })
            .disposed(by: disposeBag)

    }
}

//MVC 重构后： ---- mvvm
extension MVCViewController{
    func initMyObserveMVVM()  {
        viewModel = SimpleValidationViewModel(
            username: usernameOutlet.rx.text.orEmpty.asObservable(),
            password: passwordOutlet.rx.text.orEmpty.asObservable()
        )

        viewModel.usernameValid
            .bind(to: passwordOutlet.rx.isEnabled)
            .disposed(by: disposeBag)

        viewModel.usernameValid
            .bind(to: usernameOutlet.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.passwordValid
            .bind(to: passwordOutlet.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.everythingValid
            .bind(to: doSomethingOutlet.rx.isEnabled)
            .disposed(by: disposeBag)

        doSomethingOutlet.rx.tap
            .subscribe(onNext: { [weak self] in

                print("弹框提示")

            })
            .disposed(by: disposeBag)
    }
}
