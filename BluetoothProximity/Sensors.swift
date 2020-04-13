//
//  Sensors.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit
import CoreMotion

// Manages sensors (other than Bluetooth) and logs their data
class Sensors {
    
    // Objects
    var logger: Logger!
    var motion = CMMotionManager()
    
    // Initialize
    init() {
        
        // Get logger
        let delegate = UIApplication.shared.delegate as! AppDelegate
        logger = delegate.logger
        
    }
    
    // Start sensors
    func start() {
        startProximity()
        startAccelerometer()
        startGyroscope()
    }
    
    // Stop sensors
    func stop() {
        stopProximity()
        stopAccelerometer()
        stopGyroscope()
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
        motion.accelerometerUpdateInterval = (1.0/accelRateHz)
        motion.startAccelerometerUpdates()
        accelTimer = Timer.scheduledTimer(timeInterval: (1.0/accelRateHz), target: self, selector: #selector(newAccelData), userInfo: nil, repeats: true)
    }
    
    // Stops the accelerometer
    func stopAccelerometer() {
        accelTimer?.invalidate()
        accelTimer = nil
    }
    
    // Called when there is new accelerometer data
    @objc func newAccelData() {
        let data = motion.accelerometerData
        let s = "Accelerometer,\(data!.acceleration.x),\(data!.acceleration.y),\(data!.acceleration.z)"
        logger.write(s)
    }
    
    // -----------------------------------------------------------------------------
    // Gyroscope
    // -----------------------------------------------------------------------------
    
    // Poll frequency and timer
    var gyroRateHz = 4.0
    var gyroTimer: Timer?
    
    // Starts the gyroscope
    func startGyroscope() {
        motion.gyroUpdateInterval = (1.0/gyroRateHz)
        motion.startGyroUpdates()
        gyroTimer = Timer.scheduledTimer(timeInterval: (1.0/gyroRateHz), target: self, selector: #selector(newGyroData), userInfo: nil, repeats: true)
    }
    
    // Stops the gyroscope
    func stopGyroscope() {
        gyroTimer?.invalidate()
        gyroTimer = nil
    }
    
    // Called when there is new gyroscope data
    @objc func newGyroData() {
        let data = motion.gyroData
        let s = "Gyroscope,\(data!.rotationRate.x),\(data!.rotationRate.y),\(data!.rotationRate.z)"
        logger.write(s)
    }
}
