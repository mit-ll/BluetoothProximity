//
//  Sensors.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation

// Manages sensors (other than Bluetooth) and logs their data
class Sensors: NSObject, CLLocationManagerDelegate {
    
    // Objects
    var logger: Logger!
    var motionManager = CMMotionManager()
    var locationManager : CLLocationManager!
    var altimeter = CMAltimeter()
    var activityManager = CMMotionActivityManager()
    var pedometer = CMPedometer()
    
    // Initialize
    override init() {
        super.init()
        
        // Get logger
        let delegate = UIApplication.shared.delegate as! AppDelegate
        logger = delegate.logger
        
        // Initalize
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
    }
    
    // -----------------------------------------------------------------------------
    // Pedometer
    // -----------------------------------------------------------------------------
    
    // Start pedometer
    func startPedometer() {
        
        // Activity updates
        activityManager.startActivityUpdates(to: OperationQueue.main) {
            [weak self] (activity: CMMotionActivity?) in

            guard let activity = activity else { return }
            DispatchQueue.main.async {
                var activityState = -1
                if activity.stationary {
                    activityState = 0
                } else if activity.walking {
                    activityState = 1
                } else if activity.running {
                    activityState = 2
                } else if activity.cycling {
                    activityState = 3
                } else if activity.automotive {
                    activityState = 4
                } else if activity.unknown {
                    activityState = 5
                }
                let s = "Activity,\(activityState),\(activity.confidence.rawValue)"
                self?.logger.write(s)
            }
        }
        
        // Pedometer updates
        pedometer.startUpdates(from: Date()) {
            [weak self] pedometerData, error in
            guard let pedometerData = pedometerData, error == nil else { return }

            DispatchQueue.main.async {
                let s = "Pedometer,\(pedometerData.numberOfSteps)"
                self?.logger.write(s)
            }
        }
    }
    
    // Stop pedometer
    func stopPedometer() {
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }
    
    // -----------------------------------------------------------------------------
    // Altimeter
    // -----------------------------------------------------------------------------
    
    // Starts altimeter
    func startAltimeter() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main) { (data, error) in
                let s = "Altimeter,\(data!.relativeAltitude),\(data!.pressure)"
                self.logger.write(s)
            }
        }
    }
    
    // Stops altimeter
    func stopAltimeter() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.stopRelativeAltitudeUpdates()
        }
    }
    
    // -----------------------------------------------------------------------------
    // Compass
    // -----------------------------------------------------------------------------
    
    // Starts compass
    func startCompass() {
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    // Stops compass
    func stopCompass() {
        if CLLocationManager.headingAvailable() {
            locationManager.stopUpdatingHeading()
        }
    }
    
    // Heading data updated
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        let s = "Compass,\(heading.magneticHeading),\(heading.trueHeading),\(heading.headingAccuracy),\(heading.x),\(heading.y),\(heading.z)"
        logger.write(s)
    }
    
    // -----------------------------------------------------------------------------
    // GPS
    // -----------------------------------------------------------------------------
    
    // Starts GPS
    func startGPS() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Stops GPS
    func stopGPS() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.stopUpdatingLocation()
        }
    }
    
    // GPS data updated
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let data:CLLocation = locations[0] as CLLocation
        let s = "GPS,\(data.coordinate.latitude),\(data.coordinate.longitude),\(data.altitude),\(data.speed),\(data.course)"
        logger.write(s)
    }
    
    // GPS errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        #if DEBUG
        print("GPS error : \(error)")
        #endif
    }
    
    // -----------------------------------------------------------------------------
    // Proximity sensor
    // -----------------------------------------------------------------------------
    
    // Starts proximity sensor
    func startProximity() {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        if device.isProximityMonitoringEnabled {
            NotificationCenter.default.addObserver(self, selector: #selector(proximityChanged(notification:)), name: NSNotification.Name(rawValue: "UIDeviceProximityStateDidChangeNotification"), object: device)
        }
    }
    
    // Stops proximity sensor
    func stopProximity() {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        if device.isProximityMonitoringEnabled {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // Called when the proximity sensor is activated
    @objc func proximityChanged(notification: NSNotification) {
        let state = UIDevice.current.proximityState ? 1 : 0
        let s = "Proximity,\(state)"
        logger.write(s)
    }
    
    // -----------------------------------------------------------------------------
    // Accelerometer
    // -----------------------------------------------------------------------------
    
    // Poll frequency and timer
    var accelRateHz = 4.0
    var accelTimer: Timer?
    
    // Starts the accelerometer
    func startAccelerometer() {
        motionManager.accelerometerUpdateInterval = (1.0/accelRateHz)
        motionManager.startAccelerometerUpdates()
        accelTimer = Timer.scheduledTimer(timeInterval: (1.0/accelRateHz), target: self, selector: #selector(newAccelData), userInfo: nil, repeats: true)
    }
    
    // Stops the accelerometer
    func stopAccelerometer() {
        accelTimer?.invalidate()
        accelTimer = nil
    }
    
    // Called when there is new accelerometer data
    @objc func newAccelData() {
        let data = motionManager.accelerometerData
        let x = data?.acceleration.x
        let y = data?.acceleration.y
        let z = data?.acceleration.z
        if x != nil && y != nil && z != nil {
            let s = "Accelerometer,\(x!),\(y!),\(z!)"
            logger.write(s)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Gyroscope
    // -----------------------------------------------------------------------------
    
    // Poll frequency and timer
    var gyroRateHz = 4.0
    var gyroTimer: Timer?
    
    // Starts the gyroscope
    func startGyroscope() {
        motionManager.gyroUpdateInterval = (1.0/gyroRateHz)
        motionManager.startGyroUpdates()
        gyroTimer = Timer.scheduledTimer(timeInterval: (1.0/gyroRateHz), target: self, selector: #selector(newGyroData), userInfo: nil, repeats: true)
    }
    
    // Stops the gyroscope
    func stopGyroscope() {
        gyroTimer?.invalidate()
        gyroTimer = nil
    }
    
    // Called when there is new gyroscope data
    @objc func newGyroData() {
        let data = motionManager.gyroData
        let x = data?.rotationRate.x
        let y = data?.rotationRate.y
        let z = data?.rotationRate.z
        if x != nil && y != nil && z != nil {
            let s = "Gyroscope,\(x!),\(y!),\(z!)"
            logger.write(s)
        }
    }
}
