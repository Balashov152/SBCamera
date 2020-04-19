//
//  ViewController.swift
//  SBCamera
//
//  Created by Balashov152 on 09/03/2019.
//  Copyright (c) 2019 Balashov152. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var imageView: UIImageView! {
        didSet {
            imageView.backgroundColor = .red
        }
    }
    
    @IBAction func openCamera(_ sender: UIButton) {
        let vc = CameraViewController(nibName: "CameraViewController", bundle: nil)
        vc.modalPresentationStyle = .fullScreen
        vc.didCreatePhoto = { [weak imageView] image in
            imageView?.image = image
        }
        present(vc, animated: true, completion: nil)
    }
}

