//
//  ViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/2/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion
import CoreLocation

class ViewController: UIViewController, CBCentralManagerDelegate, CLLocationManagerDelegate {
    
    // -----------------------------------------------------------------------------
    // Parameters/options
    // -----------------------------------------------------------------------------
    
    // Detector parameters
    var M = 5                       // Samples that must cross threshold
    var N = 20                      // Total number of samples
    var rssiThresh = -65            // Threshold RSSI
    
    // Sensor parameters
    var scanRateHz = 2.0            // Number of times per second the Bluetooth scan is restarted
    var accelRateHz = 4.0           // Number of times per second to get accelerometer data
    var gyroRateHz = 4.0            // Number of times per second to get gyroscope data
    
    // Enable/disable sensors
    var enableProximity = true
    var enableAccel = true
    var enableGyto = true
    var enableLoc = true
    
    // Logging on device
    var logToFile = true
    var logFileName = "log.txt"
    
    // Printing to console
    var logToConsole = false
    
    // -----------------------------------------------------------------------------
    // Variables
    // -----------------------------------------------------------------------------
    
    var centralManager : CBCentralManager!
    var locationManager : CLLocationManager!
    var motionManager = CMMotionManager()
    var fileManager = FileManager.default
    var fileUpdater : FileHandle!
    var scanTimer = Timer()
    var accelTimer = Timer()
    var count = 0
    var logFile : URL!
    var uuids : [String] = []
    var mtx : [[Int]] = []
    var mtxPtr : [Int] = []
    var nArr : [Int] = []
    var detArr : [Int] = []
    
    // -----------------------------------------------------------------------------
    // Outlets
    // -----------------------------------------------------------------------------
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var countText: UILabel!
    @IBOutlet weak var rssiText: UILabel!
    @IBOutlet weak var nText: UILabel!
    @IBOutlet weak var mText: UILabel!
    
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
    
    @IBOutlet weak var shareButton: UIButton!
    
    // -----------------------------------------------------------------------------
    // Primary setup
    // -----------------------------------------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Pack labels into arrays
        uuidLabelArr = [uuidLabel0, uuidLabel1, uuidLabel2, uuidLabel3, uuidLabel4, uuidLabel5, uuidLabel6, uuidLabel7, uuidLabel8, uuidLabel9]
        rssiLabelArr = [rssiLabel0, rssiLabel1, rssiLabel2, rssiLabel3, rssiLabel4, rssiLabel5, rssiLabel6, rssiLabel7, rssiLabel8, rssiLabel9]
        proximityLabelArr = [proximityLabel0, proximityLabel1, proximityLabel2, proximityLabel3, proximityLabel4, proximityLabel5, proximityLabel6, proximityLabel7, proximityLabel8, proximityLabel9]
        
        // Display parameters
        nText.text = N.description
        mText.text = M.description
        rssiText.text = rssiThresh.description
        
        // Create the log file if necessary
        if logToFile {
            logFile = getDir().appendingPathComponent(logFileName)
            fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            do {
                try fileUpdater = FileHandle(forUpdating: logFile)
            }
            catch {
                print("Error making file updater")
            }
        }
        
        // Make the bluetooth manager
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // Start sensors
        if enableProximity {
            startProximitySensor()
        }
        if enableAccel {
            startAccelerometers()
        }
        if enableGyto {
            startGyroscope()
        }
        if enableLoc {
            startLocation()
        }
    }
    
    // Set up the scroll view
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = contentView.frame.size;
    }
    
    // Hide the top status bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // -----------------------------------------------------------------------------
    // General helpers
    // -----------------------------------------------------------------------------
    
    // Gets directory to save data
    func getDir() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // Gets timestamp
    func getTimestamp() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    // Writes to log file
    func writeToLogFile(_ s : String) {
        // Add a line break and write to the end of the file
        let s = s + "\n"
        fileUpdater.seekToEndOfFile()
        fileUpdater.write(s.data(using: .utf8)!)
    }
    
    // Helper for logging to console and/or file
    func writeToLog(_ s : String) {
        if logToConsole {
            print(s)
        }
        if logToFile {
            writeToLogFile(s)
        }
    }
    
    // Shares the log file when button is pressed - only if we're logging to file
    @IBAction func shareButtonPressed(_ sender: Any) {
        print("Share button pressed")
        if logToFile {
            let activityItem:NSURL = NSURL(fileURLWithPath:logFile.path)
            let activityVC = UIActivityViewController(activityItems: [activityItem], applicationActivities: nil)
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Proximity sensor functions
    // -----------------------------------------------------------------------------
    
    // Starts the proximity sensor
    func startProximitySensor() {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        if device.isProximityMonitoringEnabled {
            NotificationCenter.default.addObserver(self, selector: #selector(proximityChanged(notification:)), name: NSNotification.Name(rawValue: "UIDeviceProximityStateDidChangeNotification"), object: device)
        }
    }
    
    // If proximity sensor is activated
    @objc func proximityChanged(notification: NSNotification) {
        let proxState = UIDevice.current.proximityState ? 1 : 0
        let proxStr = "Prox," + getTimestamp() + ",\(proxState)"
        writeToLog(proxStr)
    }
    
    // -----------------------------------------------------------------------------
    // Accelerometer functions
    // -----------------------------------------------------------------------------
    
    // Starts the accelerometer sensors
    func startAccelerometers() {
        motionManager.accelerometerUpdateInterval = (1.0/accelRateHz)
        motionManager.startAccelerometerUpdates()
        accelTimer = Timer.scheduledTimer(timeInterval: (1.0/accelRateHz), target: self, selector: #selector(ViewController.getAccelerometers), userInfo: nil, repeats: true)
    }
    
    // Gets accelerometer data
    @objc func getAccelerometers() {
        let data = self.motionManager.accelerometerData
        let accelStr = "Accel," + getTimestamp() + ",\(data!.acceleration.x.description)" + ",\(data!.acceleration.y.description)" + ",\(data!.acceleration.z.description)"
        writeToLog(accelStr)
    }
    
    // -----------------------------------------------------------------------------
    // Gyroscope functions
    // -----------------------------------------------------------------------------
    
    // Starts the gyroscope sensor
    func startGyroscope() {
        motionManager.gyroUpdateInterval = (1.0/gyroRateHz)
        motionManager.startGyroUpdates()
        accelTimer = Timer.scheduledTimer(timeInterval: (1.0/gyroRateHz), target: self, selector: #selector(ViewController.getGyroscope), userInfo: nil, repeats: true)
    }
    
    // Gets gyroscope data
    @objc func getGyroscope() {
        let data = self.motionManager.gyroData
        let gyroStr = "Gyro," + getTimestamp() + ",\(data!.rotationRate.x.description)" + ",\(data!.rotationRate.y.description)" + ",\(data!.rotationRate.z.description)"
        writeToLog(gyroStr)
    }
    
    // -----------------------------------------------------------------------------
    // Location (GPS) functions
    // -----------------------------------------------------------------------------
    
    // Start getting location updates
    func startLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Got a new location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        let locStr = "Loc," + getTimestamp() + ",\(userLocation.coordinate.latitude)" + ",\(userLocation.coordinate.longitude)" + ",\(userLocation.altitude)" + ",\(userLocation.speed)" + ",\(userLocation.course)"
        writeToLog(locStr)
    }
    
    // Deal with a location error
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Location error : \(error)")
    }
    
    // -----------------------------------------------------------------------------
    // Bluetooth functions
    // -----------------------------------------------------------------------------
    
    // Start scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            statusText.text = "Running"
            statusText.textColor = UIColor.green
            print("Bluetooth is on, starting scans")
            scanTimerLoop()
        } else {
            statusText.text = "Bluetooth is off"
            statusText.textColor = UIColor.red
            print("Bluetooth is off")
        }
    }
    
    // Calls restartScan() periodically
    func scanTimerLoop() {
        scanTimer = Timer.scheduledTimer(timeInterval: (1.0/scanRateHz), target: self, selector: #selector(ViewController.restartScan), userInfo: nil, repeats: true)
    }
    
    // Restarts the scan
    @objc func restartScan() {
        if centralManager.state == .poweredOn {
            print("Restarting scan")
            centralManager.stopScan()
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    // Main function for Bluetooth processing
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Update counter for how many we've seen
        count += 1
        
        // Get UUID and write to log with RSSI
        // NOTE: could also include advertisement data, but that kind of clutters things...
        let uuid = peripheral.identifier.uuidString
        let btStr = "BT," + getTimestamp() + "," + uuid + ",\(RSSI)"
        writeToLog(btStr)
        
        // If we haven't seen this UUID, set up storage for it
        var uuidIdx = uuids.index(of: uuid)
        if uuidIdx == nil {
            uuids.append(uuid)
            uuidIdx = uuids.count - 1
            mtx.append([Int](repeating: 0, count: N))
            mtxPtr.append(0)
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
        
        // Count up to N measurements for each device
        if nArr[uuidIdx!] < N {
            nArr[uuidIdx!] += 1
        }
        // Filter out erroneous RSSI readings. Sometimes there are very large values, or
        // values that are lower than the receiver sensitivity.
        if (RSSI.intValue >= rssiThresh) && (RSSI.intValue < 0) && (RSSI.intValue > -110) {
            mtx[uuidIdx!][mtxPtr[uuidIdx!]] = 1
        } else {
            mtx[uuidIdx!][mtxPtr[uuidIdx!]] = 0
        }
        // Wrap pointer to the buffer when we reach N measurements
        mtxPtr[uuidIdx!] += 1
        if mtxPtr[uuidIdx!] == N {
            mtxPtr[uuidIdx!] = 0
        }
        // See if there are M positives within the N samples
        let s = mtx[uuidIdx!].reduce(0, +)
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
        
        // Update screen
        countText.text = count.description
        if uuidIdx! < uuidLabelArr.count {
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
    
}
