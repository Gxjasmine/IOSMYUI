//
//  ViewController.swift
//  RxSwifDemo
//
//  Created by fuzhongw on 2019/11/15.
//  Copyright © 2019 fuzhongw. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        let vcMVC = MVCViewController()
//        self.navigationController?.pushViewController(vcMVC, animated: true)

        let vc = UITestViewController()
        self.navigationController?.pushViewController(vc, animated: true)

    }

}

