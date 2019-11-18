//
//  ObservableSample.swift
//  RxSwifDemo
//
//  Created by fuzhongw on 2019/11/15.
//  Copyright © 2019 fuzhongw. All rights reserved.
//

import RxSwift
import RxCocoa

class ObservableSample: NSObject {
    let disposeBag = DisposeBag()

    static func addObservable(){

        let observable = Observable.of("A", "B", "C")

       let subscription  = observable.subscribe { event in
            print(event)
        }

        //调用这个订阅的dispose()方法 销毁
        subscription.dispose()

       _ = observable.subscribe(onNext: { (element) in
            print("onxext:\(element)")
        }, onError: { (erroe) in
            print("error:\(erroe)")
        }, onCompleted: {
            print("onCompleted")
        }) {
            print("disposed")
        }

    }

    //直接在 subscribe、bind 方法中创建观察者
    func addObservableBind(){

        let observable = Observable<Int>.interval(DispatchTimeInterval.seconds(2), scheduler: MainScheduler.instance)

        //n不被销毁
//       let subscription  = observable.subscribe { event in
//            print(event)
//        }

        observable
                 .map { "当前索引数：\($0)"}
                 .bind { (text) in
                     //收到发出的索引数后显示到label上
                    print("text:\(text)")

                 }
                 .disposed(by: disposeBag)


    }

    //使用 AnyObserver 创建观察者
    func addAnyObserver(){

        //观察者
        let observer:AnyObserver<String> = AnyObserver { (event) in
            switch event {
                case .next(let data):
                    print(data)
                case .error(let error):
                    print(error)
                case .completed:
                    print("completed")
            }
        }
        //序列
        let observable = Observable.of("a","b","c")
        _ = observable.subscribe(observer)

    }

    //使用 AnyObserver 创建观察者 配合 bindTo 方法使用
    func addAnyObserver2(){

        //观察者
        let observer:AnyObserver<String> = AnyObserver { (event) in
            switch event {
            case .next(let data):
                print(data)
            case .error(let error):
                print(error)
            case .completed:
                print("completed")
            }
        }
        //Observable序列（每隔1秒钟发出一个索引数）
        let observable = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
        observable
            .map { "当前索引数：\($0 )"}
            .bind(to: observer)
            .disposed(by: disposeBag)

    }

    //使用 AnyObserver 创建观察者 配合 bindTo 方法使用
    func addAnyObserver3(observer: Binder<String>){


        //Observable序列（每隔1秒钟发出一个索引数）
        let observable = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
        observable
            .map { "当前索引数：\($0 )"}
            .bind(to: observer)
            .disposed(by: disposeBag)

    }

}

//MARK: ---- Subjects 介绍 PublishSubject、BehaviorSubject、ReplaySubject、Variable
extension ObservableSample {

    //订阅者从他们开始订阅的时间点起，可以收到订阅后 Subject 发出的新 Event，而不会收到他们在订阅前已发出的 Event。
    func addPublishSubject()  {

        let subject = PublishSubject<String>()
        subject.onNext("111")

        //第1次订阅subject
        subject.subscribe(onNext: { (str) in
            print("第1次订阅 str:\(str)")
        }, onError: { (error) in
            print("error :\(error)")
            
        }, onCompleted: {
            print("onCompleted")
            
        }).disposed(by: disposeBag)

        subject.onNext("222")

        //第2次订阅subject
        subject.subscribe(onNext: { string in
            print("第2次订阅：", string)
        }, onCompleted:{
            print("第2次订阅：onCompleted")
        }).disposed(by: disposeBag)
        subject.onNext("333")

        //让subject结束
        subject.onCompleted()

        //subject完成后会发出.next事件了。
        subject.onNext("444")

        //subject完成后它的所有订阅（包括结束后的订阅），都能收到subject的.completed事件，
        subject.subscribe(onNext: { string in
            print("第3次订阅：", string)
        }, onCompleted:{
            print("第3次订阅：onCompleted")
        }).disposed(by: disposeBag)
    }

    //当一个订阅者来订阅它的时候，这个订阅者会立即收到 BehaviorSubjects 上一个发出的event。之后就跟正常的情况一样，它也会接收到 BehaviorSubject 之后发出的新的 event。
    func addBehaviorSubject()  {

        let subject = BehaviorSubject(value: "000")
        subject.onNext("111")

        //第1次订阅subject
        subject.subscribe { event in
            print("第1次订阅：", event)
        }.disposed(by: disposeBag)

        //发送next事件
        subject.onNext("222")

        //发送error事件
        subject.onError(NSError(domain: "local", code: 0, userInfo: nil))

        //第2次订阅subject
        subject.subscribe { event in
            print("第2次订阅：", event)
        }.disposed(by: disposeBag)

        //发送next事件 --- 被停止，不会再执行
        subject.onNext("333")
    }

    func addtimeout()  {
        //定义好每个事件里的值以及发送的时间
            let times = [
                [ "value": 1, "time": 0 ],
                [ "value": 2, "time": 0.5 ],
                [ "value": 3, "time": 1.5 ],
                [ "value": 4, "time": 4 ],
                [ "value": 5, "time": 5 ],
                [ "value": 6, "time": 1.6 ]

            ]

            //生成对应的 Observable 序列并订阅
            Observable.from(times)
                .flatMap { item in
                    return Observable.of(Int(item["value"]!))
                        .delaySubscription(Double(item["time"]!),
                                           scheduler: MainScheduler.instance)
                }
                .timeout(2, scheduler: MainScheduler.instance) //超过两秒没发出元素，则产生error事件
                .subscribe(onNext: { element in
                    print(element)
                }, onError: { error in
                    print(error)
                })
                .disposed(by: disposeBag)
        
    }
}
