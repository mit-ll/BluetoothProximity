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
    static var accelerometerEnabled = false
    static var gyroscopeEnabled = false
    static var proximityEnabled = false
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
        Settings.accelerometerEnabled = accelerometerSwitch.isOn
        Settings.gyroscopeEnabled = gyroscopeSwitch.isOn
        Settings.proximityEnabled = proximitySwitch.isOn
    }
    
    // GPS
    @IBOutlet weak var gpsSwitch: UISwitch!
    @IBAction func gpsSwitchChanged(_ sender: Any) {
        Settings.gpsEnabled = gpsSwitch.isOn
    }
    
    // Accelerometer
    @IBOutlet weak var accelerometerSwitch: UISwitch!
    @IBAction func accelerometerSwitchChanged(_ sender: Any) {
        Settings.accelerometerEnabled = accelerometerSwitch.isOn
    }
    
    // Gyroscope
    @IBOutlet weak var gyroscopeSwitch: UISwitch!
    @IBAction func gyroscopeSwitchChanged(_ sender: Any) {
        Settings.gyroscopeEnabled = gyroscopeSwitch.isOn
    }
    
    // Proximity
    @IBOutlet weak var proximitySwitch: UISwitch!
    @IBAction func proximitySwitchChanged(_ sender: Any) {
        Settings.proximityEnabled = proximitySwitch.isOn
    }
    
}
