//
//  Bluetooth.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import CoreBluetooth

// Service UUID (0x1800 = generic access) and local name
let serviceCBUUID = CBUUID(string: "1800")
let localName = "BlueProxTx"

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
    var proxRSSICount: Int!
    var otherRSSICount: Int!
    var logToFile: Bool!
    var runDetector: Bool!
    
    // Detector parameters
    let M = 5                   // Samples that must cross threshold
    let N = 20                  // Total number of samples
    let rssiThresh = -60        // Threshold RSSI
    
    // Detector storage
    var uuidIdx: Int!
    var uuidArr: [String] = []
    var nameArr: [String] = []
    var rssiArr: [Int] = []
    var mtx: [[Int]] = []
    var mtxPtr: [Int] = []
    var nArr: [Int] = []
    var detArr: [Int] = []
    
    override init() {
        super.init()
        
        // Get logger
        let delegate = UIApplication.shared.delegate as! AppDelegate
        logger = delegate.logger
        
        // Create scanner
        scanner = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // Initialize
        proxRSSICount = 0
        otherRSSICount = 0
        logToFile = false
        runDetector = false
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
        // Any time we see the desired name, increase the proximity RSSI counter
        var advName = "None"
        var advPower = -999.0
        var advTime = -1.0
        for (i, j) in advertisementData {
            if i == "kCBAdvDataLocalName" {
                advName = j as! String
                if advName == localName {
                    proxRSSICount += 1
                }
            } else if i == "kCBAdvDataTxPowerLevel" {
                advPower = j as! Double
            } else if i == "kCBAdvDataTimestamp" {
                advTime = j as! Double
            }
        }
        
        // If this wasn't the desired name, increase the other RSSI counter
        if advName == "None" {
            otherRSSICount += 1
        }
        
        // Write to log if enabled
        if logToFile {
            let s = "Bluetooth," + uuid + ",\(RSSI)" + "," + advName + ",\(advPower)" + ",\(advTime)"
            logger.write(s)
        }
        
        // Run detector processing if enabled
        if runDetector {
            
            // If this is the first time we've seen this UUID, set up storage for it
            let idx = uuidArr.index(of: uuid)
            if idx == nil {
                uuidArr.append(uuid)
                nameArr.append(advName)
                uuidIdx = uuidArr.count - 1
                rssiArr.append(0)
                mtx.append([Int](repeating: 0, count: N))
                mtxPtr.append(0)
                nArr.append(0)
                detArr.append(0)
            } else {
                uuidIdx = idx!
            }
            
            // Update RSSI and name (may have changed)
            rssiArr[uuidIdx] = RSSI.intValue
            nameArr[uuidIdx] = advName
            
            // M-of-N detector. This makes a decision for each sample based on the threshold.
            // If there are at least N samples, and M of the decisions declare detection, then
            // overall detection is declared. Possible detection values:
            //      0 - no detection
            //      1 - not enough info, but suspect no detection
            //      2 - not enough info, but suspect detection
            //      3 - detection
            
            // Count up to N measurements for each device
            if nArr[uuidIdx] < N {
                nArr[uuidIdx] += 1
            }
            // Filter out erroneous RSSI readings
            if (RSSI.intValue >= rssiThresh) && (RSSI.intValue < 0) && (RSSI.intValue > -110) {
                mtx[uuidIdx][mtxPtr[uuidIdx]] = 1
            } else {
                mtx[uuidIdx][mtxPtr[uuidIdx]] = 0
            }
            // Wrap pointer to the buffer once we reach N measurements
            mtxPtr[uuidIdx] += 1
            if mtxPtr[uuidIdx] == N {
                mtxPtr[uuidIdx] = 0
            }
            // See if there are M positives within the N samples
            let s = mtx[uuidIdx].reduce(0, +)
            if s >= M {
                if nArr[uuidIdx] == N {
                    detArr[uuidIdx] = 3    // detection
                } else {
                    detArr[uuidIdx] = 2    // not enough info, but suspect no detection
                }
            } else {
                if nArr[uuidIdx] == N {
                    detArr[uuidIdx] = 0    // 0 - no detection
                } else {
                    detArr[uuidIdx] = 1    // not enough info, but suspect no detection
                }
            }
        }
    }
    
    // Start detector processing - clear out all storage before running!
    func startDetector() {
        uuidArr = []
        nameArr = []
        rssiArr = []
        mtx = []
        mtxPtr = []
        nArr = []
        detArr = []
        runDetector = true
    }
    
    // Stop detector processing
    func stopDetector() {
        runDetector = false
    }
    
    // Reset RSSI counters
    func resetRSSICounts() {
        proxRSSICount = 0
        otherRSSICount = 0
    }
    
}
