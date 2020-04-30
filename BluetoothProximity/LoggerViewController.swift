//
//  LoggerViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
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
    var advertiser: BluetoothAdvertiser!
    var scanner: BluetoothScanner!
    
    // Initialization
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get objects from the AppDelegate
        let delegate = UIApplication.shared.delegate as! AppDelegate
        logger = delegate.logger
        sensors = delegate.sensors
        advertiser = delegate.advertiser
        scanner = delegate.scanner
        
        // Notifications for when app transitions between background and foreground
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Notification when proximity sensor is activated
        // (required since the app does not go into the background!)
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        if device.isProximityMonitoringEnabled {
            NotificationCenter.default.addObserver(self, selector: #selector(proximityChanged(notification:)), name: NSNotification.Name(rawValue: "UIDeviceProximityStateDidChangeNotification"), object: device)
        }
        
        // Initial states
        firstRun = true
        haveInitialLog = false
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
        angle = Int(angleStepper.value)
        angleLabel.text = angle.description
        isRunning = false
        runStopButton.isEnabled = false
        sendLogButton.isEnabled = false
        
        // Force steppers to respect their tintColor
        rangeStepper.setDecrementImage(rangeStepper.decrementImage(for: .normal), for: .normal)
        rangeStepper.setIncrementImage(rangeStepper.incrementImage(for: .normal), for: .normal)
        angleStepper.setDecrementImage(angleStepper.decrementImage(for: .normal), for: .normal)
        angleStepper.setIncrementImage(angleStepper.incrementImage(for: .normal), for: .normal)
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
            runStopButton.isEnabled = true
            sendLogButton.isEnabled = true
        }
    }
    
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
    
    // Settings button
    @IBOutlet weak var settingsButton: UIButton!
    
    // Run/stop button
    var firstRun: Bool!
    var isRunning: Bool!
    @IBOutlet weak var runStopButton: UIButton!
    @IBAction func runStopButtonPressed(_ sender: Any) {
        if isRunning {
            stopRun()
        } else {
            // Display a warning about locking the phone on the first run
            if firstRun {
                let alert = UIAlertController(title: "Warning", message: "Please do not lock the phone using the power button (the screen turning off can interfere with the data collection). The automatic screen lock/sleep will be disabled while logging. This message will only be displayed once.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
                    self.firstRun = false
                    self.startRun()
                }))
                present(alert, animated: true, completion: nil)
            } else {
                startRun()
            }
        }
    }
    
    // Starts running
    func startRun() {
        
        // Write range and angle to the log file
        logger.write("Range,\(range!)")
        logger.write("Angle,\(angle!)")
        
        // Start sensors
        if LoggerSettings.gpsEnabled {
            sensors.startGPS()
        }
        if LoggerSettings.accelerometerEnabled {
            sensors.startAccelerometer()
        }
        if LoggerSettings.gyroscopeEnabled {
            sensors.startGyroscope()
        }
        if LoggerSettings.proximityEnabled {
            sensors.startProximity()
        }
        if LoggerSettings.compassEnabled {
            sensors.startCompass()
        }
        if LoggerSettings.altimeterEnabled {
            sensors.startAltimeter()
        }
        if LoggerSettings.pedometerEnabled {
            sensors.startPedometer()
        }
        
        // Start Bluetooth
        advertiser.start()
        scanner.logToFile = true
        scanner.startScanForAll()
        scanner.resetRSSICounts()
        startUpdatingRSSICounts()
        
        // Lock UI
        settingsButton.isEnabled = false
        createNewLogButton.isEnabled = false
        rangeStepper.isEnabled = false
        angleStepper.isEnabled = false
        sendLogButton.isEnabled = false
        runStopButton.setTitle("Stop", for: .normal)
        
        // Override screen auto-lock, so it will stay on
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Update state
        isRunning = true
    }
    
    // Stops running
    func stopRun() {
        
        // Stop sensors
        if LoggerSettings.gpsEnabled {
            sensors.stopGPS()
        }
        if LoggerSettings.accelerometerEnabled {
            sensors.stopAccelerometer()
        }
        if LoggerSettings.gyroscopeEnabled {
            sensors.stopGyroscope()
        }
        if LoggerSettings.proximityEnabled {
            sensors.stopProximity()
        }
        if LoggerSettings.compassEnabled {
            sensors.stopCompass()
        }
        if LoggerSettings.altimeterEnabled {
            sensors.stopAltimeter()
        }
        if LoggerSettings.pedometerEnabled {
            sensors.stopPedometer()
        }
        
        // Stop Bluetooth
        advertiser.stop()
        scanner.logToFile = false
        scanner.stop()
        stopUpdatingRSSICounts()
        
        // Unlock UI
        settingsButton.isEnabled = true
        createNewLogButton.isEnabled = true
        rangeStepper.isEnabled = true
        angleStepper.isEnabled = true
        sendLogButton.isEnabled = true
        runStopButton.setTitle("Run", for: .normal)
        
        // Restore screen auto-lock
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Update state
        isRunning = false
    }
    
    // Stop any run when we leave the tab
    override func viewWillDisappear(_ animated: Bool) {
        if isRunning {
            stopRun()
        }
    }
    
    // RSSI counters - updated every second
    var rsssiTimer: Timer?
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var proxRSSILabel: UILabel!
    @IBOutlet weak var otherRSSILabel: UILabel!
    func startUpdatingRSSICounts() {
        rsssiTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateRSSICounts), userInfo: nil, repeats: true)
    }
    @objc func updateRSSICounts() {
        proxRSSILabel.text = scanner.proxRSSICount.description
        otherRSSILabel.text = scanner.otherRSSICount.description
    }
    func stopUpdatingRSSICounts() {
        rsssiTimer?.invalidate()
        rsssiTimer = nil
    }
    
    // Send log button
    @IBOutlet weak var sendLogButton: UIButton!
    @IBAction func sendLogButtonPressed(_ sender: Any) {
        
        // Present a note to record test details manually, then open the sharing interface
        let alert = UIAlertController(title: "Note", message: "Please annotate your test to include an environment (indoor, outdoor, any obstructions), phone placement (in hand, in pocket, etc.), and stance (sitting, standing). This along with any other relevant details should be included when emailing your data.", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
            
            let activityItem:NSURL = NSURL(fileURLWithPath:self.logger.fileURL.path)
            let activityVC = UIActivityViewController(activityItems: [activityItem], applicationActivities: nil)
            self.present(activityVC, animated: true, completion: nil)
            
        }))
        present(alert, animated: true, completion: nil)
        
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
            
            // Log the state
            logger.write("AppState,Background")
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
            
            // Log the state
            logger.write("AppState,Foreground")
        }
    }
    
    // Called when the proximity sensor is activated
    // If it's on, go into background mode, otherwise, come into foreground mode
    @objc func proximityChanged(notification: NSNotification) {
        let state = UIDevice.current.proximityState ? 1 : 0
        if state == 1 {
            didEnterBackground()
        } else {
            willEnterForeground()
        }
    }
}
