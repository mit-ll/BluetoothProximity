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
    static var compassEnabled = false
    static var altimeterEnabled = false
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
        compassSwitch.isOn = LoggerSettings.compassEnabled
        altimeterSwitch.isOn = LoggerSettings.altimeterEnabled
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
    
    // Compass
    @IBOutlet weak var compassSwitch: UISwitch!
    @IBAction func compassSwitchChanged(_ sender: Any) {
        LoggerSettings.compassEnabled = compassSwitch.isOn
        if LoggerSettings.compassEnabled {
            // Inform that calibration is necessary
            let alert = UIAlertController(title: "Note", message: "The compass must be calibrated to return true heading. Stand in an open area away from interference and move your phone through a figure 8 motion. If you choose not to do this, only the magnetic heading will be valid.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
            }))
            present(alert, animated: true, completion: nil)
        }
    }
    
    // Altimeter
    @IBOutlet weak var altimeterSwitch: UISwitch!
    @IBAction func altimeterSwitchChanged(_ sender: Any) {
        LoggerSettings.altimeterEnabled = altimeterSwitch.isOn
    }
    
    // Done button
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}
