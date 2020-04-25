//
//  SettingsViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/24/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit

struct Settings {
    static var gpsEnabled = false
}

class SettingsViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial settings
        Settings.gpsEnabled = gpsSwitch.isOn
    }
    
    // Switches
    @IBOutlet weak var gpsSwitch: UISwitch!
    @IBAction func gpsSwitchChanged(_ sender: Any) {
        Settings.gpsEnabled = gpsSwitch.isOn
    }
    
}
