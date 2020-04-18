//
//  GPS.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import CoreLocation

// Manages GPS and logs data
class GPS: NSObject, CLLocationManagerDelegate {
    
    // Objects
    var logger: Logger!
    var locationManager : CLLocationManager!
    
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
    
    // Starts updating location
    func start() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // Stops updating location
    func stop() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.stopUpdatingLocation()
        }
    }
    
    // Location data updated
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let data:CLLocation = locations[0] as CLLocation
        let s = "GPS,\(data.coordinate.latitude),\(data.coordinate.longitude),\(data.altitude),\(data.speed),\(data.course)"
        logger.write(s)
    }
    
    // Location errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        #if DEBUG
        print("GPS error : \(error)")
        #endif
    }
        
}
