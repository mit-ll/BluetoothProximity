//
//  UltrasonicViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 5/7/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit

class UltrasonicViewController: UIViewController {
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize
        isRunning = false
    }
    
    // Run/stop button
    var isRunning: Bool!
    @IBOutlet weak var runStopButton: UIButton!
    @IBAction func runStopButtonPressed(_ sender: Any) {
        if isRunning {
            stopRun()
        } else {
            startRun()
        }
    }
    
    // Starts running
    func startRun() {
        
        #if DEBUG
        print("Start run")
        #endif
        
        // Update UI
        runStopButton.setTitle("Stop", for: .normal)
        
        // Update state
        isRunning = true
    }
    
    // Stops running
    func stopRun() {
        
        #if DEBUG
        print("Stop run")
        #endif
        
        // Update UI
        runStopButton.setTitle("Run", for: .normal)
        
        // Update state
        isRunning = false
    }
    
}
