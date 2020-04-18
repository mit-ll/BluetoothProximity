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
    let nRows = 12
    
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
    var proxLabelArr : [UILabel] = []
    
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
        nameLabelArr = [nameLabel0, nameLabel1, nameLabel2, nameLabel3, nameLabel4, nameLabel5, nameLabel6, nameLabel7, nameLabel8, nameLabel9, nameLabel10, nameLabel11]
        rssiLabelArr = [rssiLabel0, rssiLabel1, rssiLabel2, rssiLabel3, rssiLabel4, rssiLabel5, rssiLabel6, rssiLabel7, rssiLabel8, rssiLabel9, rssiLabel10, rssiLabel11]
        proxLabelArr = [proxLabel0, proxLabel1, proxLabel2, proxLabel3, proxLabel4, proxLabel5, proxLabel6, proxLabel7, proxLabel8, proxLabel9, proxLabel11, proxLabel11]
        
        // Initialize
        isRunning = false
    }
    
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
        advertiser.stop()
        scanner.stopDetector()
        scanner.stop()
        stopUpdatingTable()
        runStopButton.setTitle("Run", for: .normal)
        isRunning = false
    }
    
    // Table is updated every second
    var tableTimer: Timer?
    func startUpdatingTable() {
        tableTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTable), userInfo: nil, repeats: true)
    }
    @objc func updateTable() {
        let n = min(scanner.uuidArr.count, nRows)
        if n > 0 {
            for i in 0...(n-1) {
                nameLabelArr[i].text = String(scanner.nameArr[i].prefix(10))
                rssiLabelArr[i].text = scanner.rssiArr[i].description
                if scanner.detArr[i] == 0 {
                    proxLabelArr[i].text = "Far"
                    proxLabelArr[i].textColor = UIColor.green
                } else if scanner.detArr[i] == 1 {
                    proxLabelArr[i].text = "Far?"
                    proxLabelArr[i].textColor = UIColor.orange
                } else if scanner.detArr[i] == 2 {
                    proxLabelArr[i].text = "Close?"
                    proxLabelArr[i].textColor = UIColor.yellow
                } else if scanner.detArr[i] == 3 {
                    proxLabelArr[i].text = "Close"
                    proxLabelArr[i].textColor = UIColor.red
                } else {
                    proxLabelArr[i].text = "?"
                    proxLabelArr[i].textColor = UIColor.white
                }
            }
        }
    }
    func stopUpdatingTable() {
        tableTimer?.invalidate()
        tableTimer = nil
    }
    func clearTable() {
        for i in 0...9 {
            nameLabelArr[i].text = "."
            rssiLabelArr[i].text = "."
            proxLabelArr[i].text = "."
            proxLabelArr[i].textColor = UIColor.white
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
