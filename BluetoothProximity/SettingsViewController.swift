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
    static var detectorM = 5
    static var detectorN = 20
    static var detectorRSSI = -60
}

class SettingsViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial enables
        Settings.gpsEnabled = gpsSwitch.isOn
        Settings.accelerometerEnabled = accelerometerSwitch.isOn
        Settings.gyroscopeEnabled = gyroscopeSwitch.isOn
        Settings.proximityEnabled = proximitySwitch.isOn
        
        // Initial detector settings
        Settings.detectorM = Int(mStepper.value)
        mLabel.text = Settings.detectorM.description
        Settings.detectorN = Int(nStepper.value)
        nLabel.text = Settings.detectorN.description
        Settings.detectorRSSI = Int(rssiStepper.value)
        rssiLabel.text = Settings.detectorRSSI.description
        
        // Force steppers to respect their tintColor
        mStepper.setDecrementImage(mStepper.decrementImage(for: .normal), for: .normal)
        mStepper.setIncrementImage(mStepper.incrementImage(for: .normal), for: .normal)
        nStepper.setDecrementImage(nStepper.decrementImage(for: .normal), for: .normal)
        nStepper.setIncrementImage(nStepper.incrementImage(for: .normal), for: .normal)
        rssiStepper.setDecrementImage(rssiStepper.decrementImage(for: .normal), for: .normal)
        rssiStepper.setIncrementImage(rssiStepper.incrementImage(for: .normal), for: .normal)
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
    
    // Detector M
    @IBOutlet weak var mLabel: UILabel!
    @IBOutlet weak var mStepper: UIStepper!
    @IBAction func mStepperChanged(_ sender: Any) {
        Settings.detectorM = Int(mStepper.value)
        mLabel.text = Settings.detectorM.description
    }
    
    // Detector N
    @IBOutlet weak var nLabel: UILabel!
    @IBOutlet weak var nStepper: UIStepper!
    @IBAction func nStepperChanged(_ sender: Any) {
        Settings.detectorN = Int(nStepper.value)
        nLabel.text = Settings.detectorN.description
    }
    
    // Detector RSSI threshold
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var rssiStepper: UIStepper!
    @IBAction func rssiStepperChanged(_ sender: Any) {
        Settings.detectorRSSI = Int(rssiStepper.value)
        rssiLabel.text = Settings.detectorRSSI.description
    }
    
}
