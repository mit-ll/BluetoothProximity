//
//  MoreInfoViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/29/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit

class MoreInfoViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // Done button
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
