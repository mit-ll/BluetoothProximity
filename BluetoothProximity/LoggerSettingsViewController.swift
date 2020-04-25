//
//  LoggerSettingsViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/25/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit

struct LoggerSettings {
    static var gpsEnabled = false
    static var accelerometerEnabled = false
    static var gyroscopeEnabled = false
    static var proximityEnabled = false
}

class LoggerSettingsViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Update switches with current logger settings
        gpsSwitch.isOn = LoggerSettings.gpsEnabled
        accelerometerSwitch.isOn = LoggerSettings.accelerometerEnabled
        gyroscopeSwitch.isOn = LoggerSettings.gyroscopeEnabled
        proximitySwitch.isOn = LoggerSettings.proximityEnabled
    }
    
    // GPS
    @IBOutlet weak var gpsSwitch: UISwitch!
    @IBAction func gpsSwitchChanged(_ sender: Any) {
        LoggerSettings.gpsEnabled = gpsSwitch.isOn
    }
    
    // Accelerometer
    @IBOutlet weak var accelerometerSwitch: UISwitch!
    @IBAction func accelerometerSwitchChanged(_ sender: Any) {
        LoggerSettings.accelerometerEnabled = accelerometerSwitch.isOn
    }
    
    // Gyroscope
    @IBOutlet weak var gyroscopeSwitch: UISwitch!
    @IBAction func gyroscopeSwitchChanged(_ sender: Any) {
        LoggerSettings.gyroscopeEnabled = gyroscopeSwitch.isOn
    }
    
    // Proximity
    @IBOutlet weak var proximitySwitch: UISwitch!
    @IBAction func proximitySwitchChanged(_ sender: Any) {
        LoggerSettings.proximityEnabled = proximitySwitch.isOn
    }
    
    // Done button
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}
