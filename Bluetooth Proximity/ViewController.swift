//
//  ViewController.swift
//  Bluetooth Proximity
//
//  Created by Michael Wentz on 4/2/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreLocation

class ViewController: UIViewController, CBCentralManagerDelegate, CLLocationManagerDelegate {
    
    // Variables
    var centralManager : CBCentralManager!
    var count = 0
    // How often to restart the scan (in seconds)
    var scanEverySec = 0.5
    var scanTimer = Timer()
    
    // Primary setup
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    // Print a debug message
    func printDebug(_ message : String){
        print("[DEBUG] " + message)
    }
    
    // Start scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            printDebug("Bluetooth is on, starting scans")
            scanTimerLoop()
        } else {
            printDebug("Bluetooth is off!")
        }
    }
    
    // Calls restartScan() every scanEverySec seconds
    func scanTimerLoop() {
        scanTimer = Timer.scheduledTimer(timeInterval: scanEverySec, target: self, selector: #selector(ViewController.restartScan), userInfo: nil, repeats: true)
    }
    
    // Restarts the scan
    @objc func restartScan() {
        printDebug("Restarting scan")
        centralManager.stopScan()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // Prints timestamp
    func printTime() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        print("Time : " + formatter.string(from: date))
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Print the current count, time, UUID, RSSI, name, and any advertised data
        count += 1
        print("Count : " + count.description)
        printTime()
        print("UUID : \(peripheral.identifier)")
        print("RSSI : \(RSSI)")
        print("Name : \(peripheral.name ?? "None")")
        for (i,j) in advertisementData {
            print("\(i) : \(j)")
        }
    }
    
}
