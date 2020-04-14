//
//  LoggerViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit

class LoggerViewController: UIViewController {
    
    // Objects from the AppDelegate
    var logger: Logger!
    var sensors: Sensors!
    var gps: GPS!
    var advertiser: BluetoothAdvertiser!
    var scanner: BluetoothScanner!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get objects from the AppDelegate
        let delegate = UIApplication.shared.delegate as! AppDelegate
        logger = delegate.logger
        sensors = delegate.sensors
        gps = delegate.gps
        advertiser = delegate.advertiser
        scanner = delegate.scanner
        
        // Notifications for when app transitions between background and foreground
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Initial states
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
        angle = Int(angleStepper.value)
        angleLabel.text = angle.description
        isRunning = false
        rssiCount = 0
    }
    
    // GPS enable/disable
    @IBOutlet weak var gpsSwitch: UISwitch!
    
    // Range in feet
    var range: Int!
    @IBOutlet weak var rangeStepper: UIStepper!
    @IBOutlet weak var rangeLabel: UILabel!
    @IBAction func rangeStepperChanged(_ sender: Any) {
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
    }
    
    // Angle in degrees
    var angle: Int!
    @IBOutlet weak var angleStepper: UIStepper!
    @IBOutlet weak var angleLabel: UILabel!
    @IBAction func angleStepperChanged(_ sender: Any) {
        angle = Int(angleStepper.value)
        angleLabel.text = angle.description
    }
    
    // Run/stop button
    var isRunning: Bool!
    @IBOutlet weak var runStopButton: UIButton!
    @IBAction func runStopButtonPressed(_ sender: Any) {
        if isRunning {
            
            // Stop any processes
            if gpsSwitch.isOn {
                gps.stop()
            }
            sensors.stop()
            advertiser.stop()
            scanner.stop()
            
            // Unlock UI
            gpsSwitch.isEnabled = true
            rangeStepper.isEnabled = true
            angleStepper.isEnabled = true
            sendButton.isEnabled = true
            runStopButton.setTitle("Run", for: .normal)
            
            // Update state
            isRunning = false

        } else {
            
            // Write range and angle to the log file
            logger.write("Range,\(range!)")
            logger.write("Angle,\(angle!)")
            
            // Start any processes
            if gpsSwitch.isOn {
                gps.start()
            }
            sensors.start()
            advertiser.start()
            scanner.startScanForAll()
            
            // Lock UI
            gpsSwitch.isEnabled = false
            rangeStepper.isEnabled = false
            angleStepper.isEnabled = false
            sendButton.isEnabled = false
            runStopButton.setTitle("Stop", for: .normal)
            
            // Update state
            isRunning = true
        }
    }
    
    // RSSI counter
    var rssiCount: Int!
    @IBOutlet weak var rssiLabel: UILabel!
    
    // Send button
    @IBOutlet weak var sendButton: UIButton!
    @IBAction func sendButtonPressed(_ sender: Any) {
        let activityItem:NSURL = NSURL(fileURLWithPath:logger.fileURL.path)
        let activityVC = UIActivityViewController(activityItems: [activityItem], applicationActivities: nil)
        present(activityVC, animated: true, completion: nil)
    }
    
    // When application moves to the background we need to make some adjustments to
    // the Bluetooth operation so it stays alive.
    @objc func didEnterBackground() {
        if isRunning {
            
            // Cycle the advertister
            advertiser.stop()
            advertiser.start()
            
            // Scanner can only scan for one service, and must do so in a timed loop
            scanner.stop()
            scanner.startScanForServiceLoop()
        }
    }
    
    // When application moves to the foreground, we can restore the original Bluetooth
    // operation
    @objc func willEnterForeground() {
        if isRunning {
            
            // Cycle the advertister
            advertiser.stop()
            advertiser.start()
            
            // Switch scanner from one service to everything
            scanner.stopScanForServiceLoop()
            scanner.startScanForAll()
        }
    }
}
