//
//  Bluetooth.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit
import CoreBluetooth

// Service UUID (0x1800 = generic access) and local name
let serviceCBUUID = CBUUID(string: "1800")
let localName = "COVID-19"

// Advertiser - broadcasts signals
class BluetoothAdvertiser: NSObject, CBPeripheralManagerDelegate {
    
    // Objects
    var service: CBMutableService!
    var advertiser: CBPeripheralManager!
    
    override init() {
        super.init()
        
        // Create service
        service = CBMutableService(type: serviceCBUUID, primary: true)
        
        // Create advertiser
        advertiser = CBPeripheralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Don't need to do anything here
    }
    
    // Starts advertising
    // This can run in the background, but the local name is ignored and the frequency may decrease
    func start() {
        if advertiser.state == .poweredOn {
            advertiser.add(service)
            let adData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [service.uuid],
                CBAdvertisementDataLocalNameKey: localName
            ]
            advertiser.startAdvertising(adData)
        }
    }
    
    // Stops advertising
    func stop() {
        if advertiser.state == .poweredOn {
            advertiser.stopAdvertising()
            advertiser.removeAllServices()
        }
    }
}

// Scanner - receives advertisements and logs data
class BluetoothScanner: NSObject, CBCentralManagerDelegate {
    
    // Objects
    var logger: Logger!
    var scanner: CBCentralManager!
    var scanTimer: Timer?
    
    // Variables
    var rssiCount: Int!
    
    override init() {
        super.init()
        
        // Get logger
        let delegate = UIApplication.shared.delegate as! AppDelegate
        logger = delegate.logger
        
        // Create scanner
        scanner = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // RSSI counter
        rssiCount = 0
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Don't need to do anything here
    }
    
    // Start scanning for any device
    // Note that this will not do anything if the app is in the background
    func startScanForAll() {
        if scanner.state == .poweredOn {
            scanner.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    // Start scanning for a service UUID
    // This can run in the background, but will not allow duplicates
    func startScanForService() {
        if scanner.state == .poweredOn {
            scanner.scanForPeripherals(withServices: [serviceCBUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    // Stop scan
    func stop() {
        if scanner.state == .poweredOn {
            scanner.stopScan()
        }
    }
    
    // Start scanning for a service UUID in a loop
    // This is a workaround to allow duplicates while in the background
    // The period is 100 ms, which is about 3x slower than while in the foreground
    func startScanForServiceLoop() {
        if scanner.state == .poweredOn {
            scanTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(BluetoothScanner.restartScan), userInfo: nil, repeats: true)
        }
    }
    
    // Restarts the scan, for use by startScanForServiceLoop()
    @objc func restartScan() {
        if scanner.state == .poweredOn {
            stop()
            startScanForService()
        }
    }
    
    // Stops scanning for a service UUID in a loop
    func stopScanForServiceLoop() {
        if scanner.state == .poweredOn {
            scanTimer?.invalidate()
            scanTimer = nil
            scanner.stopScan()
        }
    }
    
    // Callback when we receive data
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Get UUID
        let uuid = peripheral.identifier.uuidString
        
        // Parse advertisement data
        // Any time we see the desired name, increase the RSSI counter
        var advName = "None"
        var advPower = -999.0
        var advTime = -1.0
        for (i, j) in advertisementData {
            if i == "kCBAdvDataLocalName" {
                advName = j as! String
                if advName == localName {
                    rssiCount += 1
                }
            } else if i == "kCBAdvDataTxPowerLevel" {
                advPower = j as! Double
            } else if i == "kCBAdvDataTimestamp" {
                advTime = j as! Double
            }
        }
        
        // Write to log
        let s = "Bluetooth," + uuid + ",\(RSSI)" + "," + advName + ",\(advPower)" + ",\(advTime)"
        logger.write(s)
    }
    
    // Reset RSSI counter
    func resetRSSICount() {
        rssiCount = 0
    }
    
}
