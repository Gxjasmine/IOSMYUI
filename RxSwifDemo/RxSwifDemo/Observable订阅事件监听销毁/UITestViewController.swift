//
//  UITestViewController.swift
//  RxSwifDemo
//
//  Created by fuzhongw on 2019/11/15.
//  Copyright © 2019 fuzhongw. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class UITestViewController: UIViewController {
    let observableSample = ObservableSample()
    let disposeBag = DisposeBag()

    @IBOutlet weak var mLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.bindObserve3()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        observableSample.addtimeout()
//        self.bindObserve3()
    }

    func bindObserve()  {
        //观察者
        let observer: Binder<String> = Binder(mLabel) { (view, text) in
            //收到发出的索引数后显示到label上
            view.text = text
        }

        observableSample.addAnyObserver3(observer: observer)
    }

    func bindObserve2()  {
        //Observable序列（每隔0.5秒钟发出一个索引数）
        let observable = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
//        observable
//            .map { CGFloat($0) }
//            .bind(to: mLabel.fontSize) //根据索引数不断变放大字体
//            .disposed(by: disposeBag)

        observable
                  .map { CGFloat($0) }
            .bind(to: mLabel.rx.fontSize) //根据索引数不断变放大字体
                  .disposed(by: disposeBag)
    }

       func bindObserve3()  {
            //Observable序列（每隔0.5秒钟发出一个索引数）
            let observable = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)

            observable
                      .map { "当前数目：\(CGFloat($0))" }
                .bind(to: mLabel.rx.text) //根据索引数不断变放大字体
                      .disposed(by: disposeBag)
        }



}

//MARK: ---- 自定义可绑定属性
//方式一：通过对 UI 类进行扩展
extension UILabel {
    public var fontSize: Binder<CGFloat> {
        return Binder(self) { label, fontSize in
            label.font = UIFont.systemFont(ofSize: fontSize)
        }
    }
}
//方式二：通过对 Reactive 类进行扩展
extension Reactive where Base: UILabel {

    public var fontSize: Binder<CGFloat> {
        return Binder(self.base) { label, fontSize in
            label.font = UIFont.systemFont(ofSize: fontSize)
        }
    }

    /// Bindable sink for `text` property.
    public var text: Binder<String?> {
        return Binder(self.base) { label, text in
            label.text = text
        }
    }

    /// Bindable sink for `attributedText` property.
    public var attributedText: Binder<NSAttributedString?> {
        return Binder(self.base) { label, text in
            label.attributedText = text
        }
    }
}

