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

// Helper to get the type of device
public extension UIDevice {
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        func mapToDevice(identifier: String) -> String {
            switch identifier {
            case "iPod5,1":                                 return "iPod Touch 5"
            case "iPod7,1":                                 return "iPod Touch 6"
            case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
            case "iPhone4,1":                               return "iPhone 4s"
            case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
            case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
            case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
            case "iPhone7,2":                               return "iPhone 6"
            case "iPhone7,1":                               return "iPhone 6 Plus"
            case "iPhone8,1":                               return "iPhone 6s"
            case "iPhone8,2":                               return "iPhone 6s Plus"
            case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
            case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
            case "iPhone8,4":                               return "iPhone SE"
            case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
            case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
            case "iPhone10,3", "iPhone10,6":                return "iPhone X"
            case "iPhone11,2":                              return "iPhone XS"
            case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
            case "iPhone11,8":                              return "iPhone XR"
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
            case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
            case "iPad6,11", "iPad6,12":                    return "iPad 5"
            case "iPad7,5", "iPad7,6":                      return "iPad 6"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
            case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
            case "iPad6,3", "iPad6,4":                      return "iPad Pro (9.7-inch)"
            case "iPad6,7", "iPad6,8":                      return "iPad Pro (12.9-inch)"
            case "iPad7,1", "iPad7,2":                      return "iPad Pro (12.9-inch) (2nd generation)"
            case "iPad7,3", "iPad7,4":                      return "iPad Pro (10.5-inch)"
            case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":return "iPad Pro (11-inch)"
            case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":return "iPad Pro (12.9-inch) (3rd generation)"
            default:                                        return identifier
            }
        }
        
        return mapToDevice(identifier: identifier)
    }()
}

class ViewController: UIViewController, CBCentralManagerDelegate, CLLocationManagerDelegate {
    
    // -----------------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------------
    
    // Detector parameters
    var M = 5                       // Samples that must cross threshold
    var N = 20                      // Total number of samples
    var rssiThresh = -65            // Threshold RSSI
    
    // Sensor parameters
    var scanRateHz = 4.0            // Number of times per second the Bluetooth scan is restarted
    var accelRateHz = 4.0           // Number of times per second to get accelerometer data
    var gyroRateHz = 4.0            // Number of times per second to get gyroscope data
    
    // Enable/disable logging of sensors - all are enabled when the app launches
    var enableBT = true
    var enableProx = true
    var enableAccel = true
    var enableGyro = true
    var enableGPS = true
    
    // Sensor logging - when the app launches, logging is not running yet
    var enableLogger = false
    var logToConsole = false
    var logToFile = true
    var logFileName = "log.txt"
    
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
    var rssiCount = 0
    var currRange = 10
    var appliedRange = -1
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
    
    // Bluetooth radio status
    @IBOutlet weak var btStatusText: UILabel!
    
    // Sensor enables
    @IBOutlet weak var btText: UILabel!
    @IBOutlet weak var proxText: UILabel!
    @IBOutlet weak var accelText: UILabel!
    @IBOutlet weak var gyroText: UILabel!
    @IBOutlet weak var gpsText: UILabel!
    
    // Range
    @IBOutlet weak var rangeStepper: UIStepper!
    @IBOutlet weak var rangeText: UILabel!
    @IBOutlet weak var rangeUnitText: UILabel!
    @IBOutlet weak var rangeAppliedText: UILabel!
    
    // Logger on/off
    @IBOutlet weak var loggerText: UILabel!
    
    // Bluetooth counters
    @IBOutlet weak var rssiCountText: UILabel!
    @IBOutlet weak var deviceCountText: UILabel!
    
    // Detector parameters
    @IBOutlet weak var rssiText: UILabel!
    @IBOutlet weak var nText: UILabel!
    @IBOutlet weak var mText: UILabel!
    
    // UUID label group
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
    var rssiLabelArr : [UILabel] = []
    
    // Proximity label group
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
        
    // -----------------------------------------------------------------------------
    // Primary setup
    // -----------------------------------------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Prevent screen from turning off
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Pack labels into arrays
        uuidLabelArr = [uuidLabel0, uuidLabel1, uuidLabel2, uuidLabel3, uuidLabel4, uuidLabel5, uuidLabel6, uuidLabel7, uuidLabel8, uuidLabel9]
        rssiLabelArr = [rssiLabel0, rssiLabel1, rssiLabel2, rssiLabel3, rssiLabel4, rssiLabel5, rssiLabel6, rssiLabel7, rssiLabel8, rssiLabel9]
        proximityLabelArr = [proximityLabel0, proximityLabel1, proximityLabel2, proximityLabel3, proximityLabel4, proximityLabel5, proximityLabel6, proximityLabel7, proximityLabel8, proximityLabel9]
        
        // Display the detector parameters
        nText.text = N.description
        mText.text = M.description
        rssiText.text = rssiThresh.description
        
        // Create the log file
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
        
        // Log the device model
        let modelName = UIDevice.modelName
        print("Device: " + modelName)
        let modelStr = "Device," + getTimestamp() + "," + modelName
        writeToLog(modelStr)
        
        // Make the bluetooth manager
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // Start sensors
        if enableProx {
            startProximitySensor()
        }
        if enableAccel {
            startAccelerometers()
        }
        if enableGyro {
            startGyroscope()
        }
        if enableGPS {
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
    // Logging functions
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
    
    // Log to console and/or file
    func writeToLog(_ s : String) {
        if logToConsole {
            print(s)
        }
        if logToFile {
            writeToLogFile(s)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Button and switch callbacks
    // -----------------------------------------------------------------------------
    
    // Changes sensor switch enable text and color
    func updateSwitchText(s : Bool, u : UILabel) {
        if s {
            u.text = "Yes"
            u.textColor = UIColor.green
        } else {
            u.text = "No"
            u.textColor = UIColor.gray
        }
    }
    
    @IBAction func btSwitchChanged(_ sender: Any) {
        enableBT.toggle()
        updateSwitchText(s: enableBT, u: btText)
        print("Bluetooth switch changed to \(enableBT)")
    }
    
    @IBAction func proxSwitchChanged(_ sender: Any) {
        enableProx.toggle()
        updateSwitchText(s: enableProx, u: proxText)
        print("Proximity switch changed to \(enableProx)")
    }
    
    @IBAction func accelSwitchChanged(_ sender: Any) {
        enableAccel.toggle()
        updateSwitchText(s: enableAccel, u: accelText)
        print("Accelerometer switch changed to \(enableAccel)")
    }
    
    @IBAction func gyroSwitchChanged(_ sender: Any) {
        enableGyro.toggle()
        updateSwitchText(s: enableGyro, u: gyroText)
        print("Gyroscope switch changed to \(enableGyro)")
    }
    
    @IBAction func gpsSwitchChanged(_ sender: Any) {
        enableGPS.toggle()
        updateSwitchText(s: enableGPS, u: gpsText)
        print("GPS switch changed to \(enableGPS)")
    }
    
    // Applies range (writes to log) and updates range text color to green
    @IBAction func rangeButtonPressed(_ sender: Any) {
        if currRange != appliedRange {
            print("Applying range of \(currRange)")
            let rangeStr = "Range," + getTimestamp() + ",\(currRange)"
            writeToLog(rangeStr)
            appliedRange = currRange
            rangeText.textColor = UIColor.green
            rangeUnitText.textColor = UIColor.green
            rangeAppliedText.text = "Range is applied"
            rangeAppliedText.textColor = UIColor.green
        } else {
            print("Range of \(currRange) is already applied")
        }
    }
    
    // Updates range text. Anytime the range has not been applied it is red.
    @IBAction func rangeChanged(_ sender: Any) {
        currRange = Int(rangeStepper.value)
        print("Range changed to \(currRange)")
        rangeText.text = currRange.description
        if currRange != appliedRange {
            rangeText.textColor = UIColor.red
            rangeUnitText.textColor = UIColor.red
            rangeAppliedText.text = "Range is not applied!"
            rangeAppliedText.textColor = UIColor.red
        } else {
            rangeText.textColor = UIColor.green
            rangeUnitText.textColor = UIColor.green
            rangeAppliedText.text = "Range is applied"
            rangeAppliedText.textColor = UIColor.green
        }
    }
    
    // Enable/disable logging switch
    @IBAction func loggerSwitchChanged(_ sender: Any) {
        enableLogger.toggle()
        print("Logger enable changed to \(enableLogger)")
        if enableLogger {
            loggerText.text = "Running"
            loggerText.textColor = UIColor.green
        } else {
            loggerText.text = "Off"
            loggerText.textColor = UIColor.gray
        }
    }
    
    // Shares the log file (only if one exists)
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
        if enableProx && enableLogger {
            let proxState = UIDevice.current.proximityState ? 1 : 0
            let proxStr = "Prox," + getTimestamp() + ",\(proxState)"
            writeToLog(proxStr)
        }
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
        if enableAccel && enableLogger {
            let data = self.motionManager.accelerometerData
            let accelStr = "Accel," + getTimestamp() + ",\(data!.acceleration.x.description)" + ",\(data!.acceleration.y.description)" + ",\(data!.acceleration.z.description)"
            writeToLog(accelStr)
        }
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
        if enableGyro && enableLogger {
            let data = self.motionManager.gyroData
            let gyroStr = "Gyro," + getTimestamp() + ",\(data!.rotationRate.x.description)" + ",\(data!.rotationRate.y.description)" + ",\(data!.rotationRate.z.description)"
            writeToLog(gyroStr)
        }
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
        if enableGPS && enableLogger {
            let userLocation:CLLocation = locations[0] as CLLocation
            let locStr = "GPS," + getTimestamp() + ",\(userLocation.coordinate.latitude)" + ",\(userLocation.coordinate.longitude)" + ",\(userLocation.altitude)" + ",\(userLocation.speed)" + ",\(userLocation.course)"
            writeToLog(locStr)
        }
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
            btStatusText.text = "Bluetooth Radio is on"
            btStatusText.textColor = UIColor.green
            print("Bluetooth is on, starting scans")
            scanTimerLoop()
        } else {
            btStatusText.text = "Bluetooth Radio is off!"
            btStatusText.textColor = UIColor.red
            print("Bluetooth is off")
        }
    }
    
    // Calls restartScan() periodically
    func scanTimerLoop() {
        scanTimer = Timer.scheduledTimer(timeInterval: (1.0/scanRateHz), target: self, selector: #selector(ViewController.restartScan), userInfo: nil, repeats: true)
    }
    
    // Restarts the scan
    @objc func restartScan() {
        if enableBT {
            if centralManager.state == .poweredOn {
                print("Restarting scan")
                centralManager.stopScan()
                centralManager.scanForPeripherals(withServices: nil, options: nil)
            }
        }
    }
    
    // Main function for Bluetooth processing
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Get UUID and write to log with RSSI
        // NOTE: could also include advertisement data, but that kind of clutters things...
        rssiCount += 1
        let uuid = peripheral.identifier.uuidString
        if enableBT && enableLogger {
            let btStr = "BT," + getTimestamp() + "," + uuid + ",\(RSSI)"
            writeToLog(btStr)
        }
        
        // If we haven't seen this UUID, set up storage for it
        var uuidIdx = uuids.index(of: uuid)
        if uuidIdx == nil {
            uuids.append(uuid)
            uuidIdx = uuids.count - 1
            mtx.append([Int](repeating: 0, count: N))
            mtxPtr.append(0)
            nArr.append(0)
            detArr.append(0)
            deviceCountText.text = uuids.count.description
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
        rssiCountText.text = rssiCount.description
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
