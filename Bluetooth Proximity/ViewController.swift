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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Primary setup
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is on")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth is off!")
        }
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
