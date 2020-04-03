//
//  ViewController.swift
//  Bluetooth Proximity
//
//  Created by Michael Wentz on 4/2/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate {
    
    // Parameters
    var scanEverySec = 0.5          // How often the scan is restarted  (seconds)
    var rssiThresh = -65            // Threshold RSSI, dBm
    var M = 5                       // Samples that must cross threshold
    var N = 20                      // Total number of samples
    
    // Debugging
    var printDebug = false
    
    // Variables
    var centralManager : CBCentralManager!
    var count = 0
    var scanTimer = Timer()
    var uuids : [String] = []
    var mMtx : [[Int]] = []
    var mPtr : [Int] = []
    var nArr : [Int] = []
    var detArr : [Int] = []
    
    // Outlets
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var countText: UILabel!
    @IBOutlet weak var rssiText: UILabel!
    
    @IBOutlet weak var uuidLabel0: UILabel!
    @IBOutlet weak var uuidLabel1: UILabel!
    @IBOutlet weak var uuidLabel2: UILabel!
    @IBOutlet weak var uuidLabel3: UILabel!
    @IBOutlet weak var uuidLabel4: UILabel!
    @IBOutlet weak var uuidLabel5: UILabel!
    @IBOutlet weak var uuidLabel6: UILabel!
    @IBOutlet weak var uuidLabel7: UILabel!
    @IBOutlet weak var uuidLabel8: UILabel!
    @IBOutlet weak var uuidLabel9: UILabel!
    var uuidLabelArr : [UILabel] = []
    
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
    var rssiLabelArr : [UILabel] = []
    
    @IBOutlet weak var proximityLabel0: UILabel!
    @IBOutlet weak var proximityLabel1: UILabel!
    @IBOutlet weak var proximityLabel2: UILabel!
    @IBOutlet weak var proximityLabel3: UILabel!
    @IBOutlet weak var proximityLabel4: UILabel!
    @IBOutlet weak var proximityLabel5: UILabel!
    @IBOutlet weak var proximityLabel6: UILabel!
    @IBOutlet weak var proximityLabel7: UILabel!
    @IBOutlet weak var proximityLabel8: UILabel!
    @IBOutlet weak var proximityLabel9: UILabel!
    var proximityLabelArr : [UILabel] = []
    
    // Primary setup
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Pack labels into arrays
        uuidLabelArr = [uuidLabel0, uuidLabel1, uuidLabel2, uuidLabel3, uuidLabel4, uuidLabel5, uuidLabel6, uuidLabel7, uuidLabel8, uuidLabel9]
        rssiLabelArr = [rssiLabel0, rssiLabel1, rssiLabel2, rssiLabel3, rssiLabel4, rssiLabel5, rssiLabel6, rssiLabel7, rssiLabel8, rssiLabel9]
        proximityLabelArr = [proximityLabel0, proximityLabel1, proximityLabel2, proximityLabel3, proximityLabel4, proximityLabel5, proximityLabel6, proximityLabel7, proximityLabel8, proximityLabel9]
        
        // Initialize threshold
        rssiText.text = rssiThresh.description
        
        // Make the bluetooth manager
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    // Start scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            statusText.text = "Running"
            statusText.textColor = UIColor.green
            if printDebug {
                print("Bluetooth is on, starting scans")
            }
            scanTimerLoop()
        } else {
            statusText.text = "Bluetooth is off"
            statusText.textColor = UIColor.red
            if printDebug {
                print("Bluetooth is off")
            }
        }
    }
    
    // Calls restartScan() every scanEverySec seconds
    func scanTimerLoop() {
        scanTimer = Timer.scheduledTimer(timeInterval: scanEverySec, target: self, selector: #selector(ViewController.restartScan), userInfo: nil, repeats: true)
    }
    
    // Restarts the scan
    @objc func restartScan() {
        if printDebug {
            print("Restarting scan")
        }
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
        let uuid = peripheral.identifier.uuidString
        if printDebug {
            print("Count : " + count.description)
            printTime()
            print("UUID : " + uuid)
            print("RSSI : \(RSSI)")
            print("Name : \(peripheral.name ?? "None")")
            for (i,j) in advertisementData {
                print("\(i) : \(j)")
            }
        }
        
        // If we haven't seen this UUID, set up storage for it
        var uuidIdx = uuids.index(of: uuid)
        if uuidIdx == nil {
            uuids.append(uuid)
            uuidIdx = uuids.count - 1
            mMtx.append([Int](repeating: 0, count: M))
            mPtr.append(0)
            nArr.append(0)
            detArr.append(0)
        }
        
        // M-of-N detector. This makes a decision for each sample based on the threshold.
        // If there are at least N samples, and M of the decisions declare detection, then
        // overall detection is declared. Possible detection values:
        //      0 - no detection
        //      1 - not enough info, but suspect no detection
        //      2 - not enough info, but suspect detection
        //      3 - detection
        if nArr[uuidIdx!] < N {
            nArr[uuidIdx!] += 1
        }
        if RSSI.intValue >= rssiThresh {
            mMtx[uuidIdx!][mPtr[uuidIdx!]] = 1
        } else {
            mMtx[uuidIdx!][mPtr[uuidIdx!]] = 0
        }
        mPtr[uuidIdx!] += 1
        if mPtr[uuidIdx!] == M {
            mPtr[uuidIdx!] = 0
        }
        let s = mMtx[uuidIdx!].reduce(0, +)
        if s >= M {
            if nArr[uuidIdx!] == N {
                detArr[uuidIdx!] = 3
            } else {
                detArr[uuidIdx!] = 2
            }
        } else {
            if nArr[uuidIdx!] == N {
                detArr[uuidIdx!] = 0
            } else {
                detArr[uuidIdx!] = 1
            }
        }
        
        // TODO
        // - Add hysterisis
        // - Replace far detections with close ones if they can't be displayed

        // Update screen
        countText.text = count.description
        uuidLabelArr[uuidIdx!].text = String(uuid.prefix(4))
        rssiLabelArr[uuidIdx!].text = RSSI.description
        let mNstr = "(\(s)/\(nArr[uuidIdx!]))"
        if detArr[uuidIdx!] == 0 {
            proximityLabelArr[uuidIdx!].text = "Far " + mNstr
            proximityLabelArr[uuidIdx!].textColor = UIColor.green
        } else if detArr[uuidIdx!] == 1 {
            proximityLabelArr[uuidIdx!].text = "Far? " + mNstr
            proximityLabelArr[uuidIdx!].textColor = UIColor.orange
        } else if detArr[uuidIdx!] == 2 {
            proximityLabelArr[uuidIdx!].text = "Close? " + mNstr
            proximityLabelArr[uuidIdx!].textColor = UIColor.yellow
        } else if detArr[uuidIdx!] == 3 {
            proximityLabelArr[uuidIdx!].text = "Close " + mNstr
            proximityLabelArr[uuidIdx!].textColor = UIColor.red
        }

    }
    
}
