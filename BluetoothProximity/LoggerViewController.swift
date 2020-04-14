//
//  LoggerViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit

class LoggerViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
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
        haveInitialLog = false
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
        angle = Int(angleStepper.value)
        angleLabel.text = angle.description
        isRunning = false
    }
    
    // Create new log. For the first log, just do it - but for subsequent ones, ask,
    // since this will also delete them.
    var haveInitialLog: Bool!
    @IBOutlet weak var createNewLogButton: UIButton!
    @IBAction func createNewLogButtonPressed(_ sender: Any) {
        if haveInitialLog {
            
            // Warn before deleting old log
            let alert = UIAlertController(title: "Warning", message: "Creating a new log will delete the old log. To avoid losing data, make sure the old log has been sent off of this device before continuing.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
                self.logger.deleteLogs()
                self.logger.createNewLog()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
                // Nothing to do here
            }))
            present(alert, animated: true, completion: nil)
            
        } else {
            logger.createNewLog()
            haveInitialLog = true
        }
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
        
        if haveInitialLog && isRunning {
            
            // Stop running
            
            // Stop any processes
            if gpsSwitch.isOn {
                gps.stop()
            }
            sensors.stop()
            advertiser.stop()
            scanner.stop()
            stopUpdatingRSSICount()
            
            // Unlock UI
            createNewLogButton.isEnabled = true
            gpsSwitch.isEnabled = true
            rangeStepper.isEnabled = true
            angleStepper.isEnabled = true
            sendLogButton.isEnabled = true
            runStopButton.setTitle("Run", for: .normal)
            
            // Update state
            isRunning = false

        } else if haveInitialLog {
            
            // Start running
            
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
            scanner.resetRSSICount()
            startUpdatingRSSICount()
            
            // Lock UI
            createNewLogButton.isEnabled = false
            gpsSwitch.isEnabled = false
            rangeStepper.isEnabled = false
            angleStepper.isEnabled = false
            sendLogButton.isEnabled = false
            runStopButton.setTitle("Stop", for: .normal)
            
            // Update state
            isRunning = true
            
        } else {
            
            // Not ready to run - no log file
            let alert = UIAlertController(title: "Warning", message: "No log file exists. Create a log, then come back here.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
                // Nothing to do here
            }))
            present(alert, animated: true, completion: nil)
            
        }
    }
    
    // RSSI counter - updated every second
    var rsssiTimer: Timer?
    @IBOutlet weak var rssiLabel: UILabel!
    func startUpdatingRSSICount() {
        rsssiTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateRSSICount), userInfo: nil, repeats: true)
    }
    @objc func updateRSSICount() {
        rssiLabel.text = scanner.rssiCount.description
    }
    func stopUpdatingRSSICount() {
        rsssiTimer?.invalidate()
        rsssiTimer = nil
    }
    
    // Send log button
    @IBOutlet weak var sendLogButton: UIButton!
    @IBAction func sendLogButtonPressed(_ sender: Any) {
        if haveInitialLog {
            let activityItem:NSURL = NSURL(fileURLWithPath:logger.fileURL.path)
            let activityVC = UIActivityViewController(activityItems: [activityItem], applicationActivities: nil)
            present(activityVC, animated: true, completion: nil)
        }
        else {
            // No log file to send yet
            let alert = UIAlertController(title: "Warning", message: "No log file exists. Create a log and collect data, then come back here.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
                // Nothing to do here
            }))
            present(alert, animated: true, completion: nil)
        }
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
