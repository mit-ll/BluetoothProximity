//
//  DetectorSettingsViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/25/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit

struct DetectorSettings {
    static var M = 5
    static var N = 20
    static var rssiThresh = -60
}

class DetectorSettingsViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Update steppers/text with current detector settings
        rssiStepper.value = Double(DetectorSettings.rssiThresh)
        rssiLabel.text = DetectorSettings.rssiThresh.description
        nStepper.value = Double(DetectorSettings.N)
        nLabel.text = DetectorSettings.N.description
        mStepper.value = Double(DetectorSettings.M)
        mLabel.text = DetectorSettings.M.description
        
        // Force steppers to respect their tintColor
        rssiStepper.setDecrementImage(rssiStepper.decrementImage(for: .normal), for: .normal)
        rssiStepper.setIncrementImage(rssiStepper.incrementImage(for: .normal), for: .normal)
        nStepper.setDecrementImage(nStepper.decrementImage(for: .normal), for: .normal)
        nStepper.setIncrementImage(nStepper.incrementImage(for: .normal), for: .normal)
        mStepper.setDecrementImage(mStepper.decrementImage(for: .normal), for: .normal)
        mStepper.setIncrementImage(mStepper.incrementImage(for: .normal), for: .normal)
    }
    
    // RSSI threshold stepper
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var rssiStepper: UIStepper!
    @IBAction func rssiStepperChanged(_ sender: Any) {
        DetectorSettings.rssiThresh = Int(rssiStepper.value)
        rssiLabel.text = DetectorSettings.rssiThresh.description
    }

    // N stepper
    @IBOutlet weak var nLabel: UILabel!
    @IBOutlet weak var nStepper: UIStepper!
    @IBAction func nStepperChanged(_ sender: Any) {
        DetectorSettings.N = Int(nStepper.value)
        nLabel.text = DetectorSettings.N.description
    }
    
    // M stepper
    @IBOutlet weak var mLabel: UILabel!
    @IBOutlet weak var mStepper: UIStepper!
    @IBAction func mStepperChanged(_ sender: Any) {
        DetectorSettings.M = Int(mStepper.value)
        mLabel.text = DetectorSettings.M.description
    }
    
    // Done button
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
