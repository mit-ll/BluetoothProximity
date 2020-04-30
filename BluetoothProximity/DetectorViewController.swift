//
//  LiveViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit

class DetectorViewController: UIViewController {
    
    // Number of rows in the table
    let nRows = 15
    
    // Name label group
    @IBOutlet weak var nameLabel0: UILabel!
    @IBOutlet weak var nameLabel1: UILabel!
    @IBOutlet weak var nameLabel2: UILabel!
    @IBOutlet weak var nameLabel3: UILabel!
    @IBOutlet weak var nameLabel4: UILabel!
    @IBOutlet weak var nameLabel5: UILabel!
    @IBOutlet weak var nameLabel6: UILabel!
    @IBOutlet weak var nameLabel7: UILabel!
    @IBOutlet weak var nameLabel8: UILabel!
    @IBOutlet weak var nameLabel9: UILabel!
    @IBOutlet weak var nameLabel10: UILabel!
    @IBOutlet weak var nameLabel11: UILabel!
    @IBOutlet weak var nameLabel12: UILabel!
    @IBOutlet weak var nameLabel13: UILabel!
    @IBOutlet weak var nameLabel14: UILabel!
    var nameLabelArr : [UILabel] = []
    
    // RSSI label group
    @IBOutlet weak var rssiLabel0: UILabel!
    @IBOutlet weak var rssiLabel1: UILabel!
    @IBOutlet weak var rssiLabel2: UILabel!
    @IBOutlet weak var rssiLabel3: UILabel!
    @IBOutlet weak var rssiLabel4: UILabel!
    @IBOutlet weak var rssiLabel5: UILabel!
    @IBOutlet weak var rssiLabel6: UILabel!
    @IBOutlet weak var rssiLabel7: UILabel!
    @IBOutlet weak var rssiLabel8: UILabel!
    @IBOutlet weak var rssiLabel9: UILabel!
    @IBOutlet weak var rssiLabel10: UILabel!
    @IBOutlet weak var rssiLabel11: UILabel!
    @IBOutlet weak var rssiLabel12: UILabel!
    @IBOutlet weak var rssiLabel13: UILabel!
    @IBOutlet weak var rssiLabel14: UILabel!
    var rssiLabelArr : [UILabel] = []
    
    // Proximity label group
    @IBOutlet weak var proxLabel0: UILabel!
    @IBOutlet weak var proxLabel1: UILabel!
    @IBOutlet weak var proxLabel2: UILabel!
    @IBOutlet weak var proxLabel3: UILabel!
    @IBOutlet weak var proxLabel4: UILabel!
    @IBOutlet weak var proxLabel5: UILabel!
    @IBOutlet weak var proxLabel6: UILabel!
    @IBOutlet weak var proxLabel7: UILabel!
    @IBOutlet weak var proxLabel8: UILabel!
    @IBOutlet weak var proxLabel9: UILabel!
    @IBOutlet weak var proxLabel10: UILabel!
    @IBOutlet weak var proxLabel11: UILabel!
    @IBOutlet weak var proxLabel12: UILabel!
    @IBOutlet weak var proxLabel13: UILabel!
    @IBOutlet weak var proxLabel14: UILabel!
    var proxLabelArr : [UILabel] = []
    
    // Duration label group
    @IBOutlet weak var durLabel0: UILabel!
    @IBOutlet weak var durLabel1: UILabel!
    @IBOutlet weak var durLabel2: UILabel!
    @IBOutlet weak var durLabel3: UILabel!
    @IBOutlet weak var durLabel4: UILabel!
    @IBOutlet weak var durLabel5: UILabel!
    @IBOutlet weak var durLabel6: UILabel!
    @IBOutlet weak var durLabel7: UILabel!
    @IBOutlet weak var durLabel8: UILabel!
    @IBOutlet weak var durLabel9: UILabel!
    @IBOutlet weak var durLabel10: UILabel!
    @IBOutlet weak var durLabel11: UILabel!
    @IBOutlet weak var durLabel12: UILabel!
    @IBOutlet weak var durLabel13: UILabel!
    @IBOutlet weak var durLabel14: UILabel!
    var durLabelArr : [UILabel] = []
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // Objects from the AppDelegate
    var advertiser: BluetoothAdvertiser!
    var scanner: BluetoothScanner!
    
    // Initialization
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get objects from the AppDelegate
        let delegate = UIApplication.shared.delegate as! AppDelegate
        advertiser = delegate.advertiser
        scanner = delegate.scanner
        
        // Notifications for when app transitions between background and foreground
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Pack labels into arrays
        nameLabelArr = [nameLabel0, nameLabel1, nameLabel2, nameLabel3, nameLabel4, nameLabel5, nameLabel6, nameLabel7, nameLabel8, nameLabel9, nameLabel10, nameLabel11, nameLabel12, nameLabel13, nameLabel14]
        rssiLabelArr = [rssiLabel0, rssiLabel1, rssiLabel2, rssiLabel3, rssiLabel4, rssiLabel5, rssiLabel6, rssiLabel7, rssiLabel8, rssiLabel9, rssiLabel10, rssiLabel11, rssiLabel12, rssiLabel13, rssiLabel14]
        proxLabelArr = [proxLabel0, proxLabel1, proxLabel2, proxLabel3, proxLabel4, proxLabel5, proxLabel6, proxLabel7, proxLabel8, proxLabel9, proxLabel10, proxLabel11, proxLabel12, proxLabel3, proxLabel4]
        durLabelArr = [durLabel0, durLabel1, durLabel2, durLabel3, durLabel4, durLabel5, durLabel6, durLabel7, durLabel8, durLabel9, durLabel10, durLabel11, durLabel12, durLabel13, durLabel14]
        
        // Initialize
        isRunning = false
    }
    
    // Settings button
    @IBOutlet weak var settingsButton: UIButton!
    
    // Run/stop button
    var isRunning: Bool!
    @IBOutlet weak var runStopButton: UIButton!
    @IBAction func runStopButtonPressed(_ sender: Any) {
        if isRunning {
            stopRun()
        } else {
            startRun()
        }
    }
    
    // Starts running
    func startRun() {
        settingsButton.isEnabled = false
        advertiser.start()
        scanner.logToFile = false
        scanner.startDetector()
        scanner.startScanForAll()
        clearTable()
        startUpdatingTable()
        runStopButton.setTitle("Stop", for: .normal)
        isRunning = true
    }
    
    // Stops running
    func stopRun() {
        settingsButton.isEnabled = true
        advertiser.stop()
        scanner.stopDetector()
        scanner.stop()
        stopUpdatingTable()
        runStopButton.setTitle("Run", for: .normal)
        isRunning = false
    }
    
    // Table is updated every second
    @IBOutlet weak var additionalDevicesLabel: UILabel!
    var tableTimer: Timer?
    func startUpdatingTable() {
        tableTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTable), userInfo: nil, repeats: true)
    }
    @objc func updateTable() {
                
        // If there's data, populate the table
        let nAvail = scanner.uuidArr.count
        var nAdditional = 0
        if nAvail > 0 {
            
            // Clear everything
            clearTable()
            
            // Loop through all entries to see if we should display them
            var nRowsDisp = 0
            let tNow = NSDate().timeIntervalSince1970
            for i in 0...(nAvail-1) {
                
                // If this device is beyond the time threshold, don't display it, and
                // reset its data for if/when it returns
                let tDiff = Int(tNow - scanner.tLastArr[i])
                if tDiff >= scanner.tThresh {
                    scanner.resetDataAt(index: i)
                    continue
                }
                
                // Update table if we can, otherwise add to the additional device count
                if nRowsDisp < nRows {
                                
                    // Name - if it's None, display the first 8 characters of the UUID
                    if scanner.nameArr[i] == "None" {
                        nameLabelArr[nRowsDisp].text = String(scanner.uuidArr[i].prefix(8))
                    } else {
                        nameLabelArr[nRowsDisp].text = String(scanner.nameArr[i].prefix(10))
                    }
                    
                    // RSSI
                    rssiLabelArr[nRowsDisp].text = scanner.rssiArr[i].description
                    
                    // Proximity estimate
                    if scanner.detArr[i] == 0 {
                        proxLabelArr[nRowsDisp].text = "Far"
                        proxLabelArr[nRowsDisp].textColor = UIColor.green
                    } else if scanner.detArr[i] == 1 {
                        proxLabelArr[nRowsDisp].text = "Far?"
                        proxLabelArr[nRowsDisp].textColor = UIColor.orange
                    } else if scanner.detArr[i] == 2 {
                        proxLabelArr[nRowsDisp].text = "Close?"
                        proxLabelArr[nRowsDisp].textColor = UIColor.yellow
                    } else if scanner.detArr[i] == 3 {
                        proxLabelArr[nRowsDisp].text = "Close"
                        proxLabelArr[nRowsDisp].textColor = UIColor.red
                    } else {
                        proxLabelArr[nRowsDisp].text = "?"
                        proxLabelArr[nRowsDisp].textColor = UIColor.white
                    }
                    
                    // Duration
                    durLabelArr[nRowsDisp].text = scanner.durArr[i].description
                    
                    // Update number of rows displayed
                    nRowsDisp += 1
                    
                } else {
                    nAdditional += 1
                }
                
            }
        }
        
        // Update label for number of additional devices
        additionalDevicesLabel.text = nAdditional.description
        
    }
    func stopUpdatingTable() {
        tableTimer?.invalidate()
        tableTimer = nil
    }
    func clearTable() {
        for i in 0...(nRows-1) {
            nameLabelArr[i].text = "."
            rssiLabelArr[i].text = "."
            proxLabelArr[i].text = "."
            proxLabelArr[i].textColor = UIColor.white
            durLabelArr[i].text = "."
        }
    }
    
    // Stop any run when we leave the tab
    override func viewWillDisappear(_ animated: Bool) {
        if isRunning {
            stopRun()
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
