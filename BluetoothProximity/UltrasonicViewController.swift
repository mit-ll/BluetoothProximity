//
//  UltrasonicViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 5/7/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import AVFoundation

class UltrasonicViewController: UIViewController {
    
    // Objects
    var tx: audioTx!
    var engine: AVAudioEngine!
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Initialize
        tx = audioTx()
        engine = AVAudioEngine()
        isRunning = false
        
        // Connect components
        engine.attach(tx.player)
        engine.connect(tx.player, to:engine.outputNode, format: tx.buff.format)
        
        // Startup
        do {
            try engine.start()
        } catch {
            #if DEBUG
            print("AVAudioEngine failed to start")
            #endif
        }
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

        // Start transmitter
        tx.startLoop()
        
        // Update UI
        runStopButton.setTitle("Stop", for: .normal)
        
        // Update state
        isRunning = true
    }
    
    // Stops running
    func stopRun() {

        // Stop transmitter
        tx.stopLoop()
        
        // Update UI
        runStopButton.setTitle("Run", for: .normal)
        
        // Update state
        isRunning = false
    }
    
}

// Writes data samples to file
class dataWriter {
    
    // Objects
    var fileManager: FileManager!
    var fileHandle: FileHandle!
    var fileURL: URL!
    
    // Initialize
    init() {
        fileManager = FileManager.default
    }
    
    // Gets directory to save data
    func getDir() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // Creates a new file
    func createFile(fileName: String) {
        fileURL = getDir().appendingPathComponent(fileName)
        fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        do {
            try fileHandle = FileHandle(forUpdating: fileURL)
        }
        catch {
            #if DEBUG
            print("Failed to create FileHandle")
            #endif
        }
    }
    
    // Writes an array of samples to file
    func writeArray(data: [Float32]) {
        fileHandle.seekToEndOfFile()
        let tmp = data.withUnsafeBytes{Array($0)}
        fileHandle.write(Data(tmp))
    }
    
}

// Transmitter - sends signals
class audioTx {
    
    // Objects
    var buff: AVAudioPCMBuffer!
    var player: AVAudioPlayerNode!
    var sendTimer: Timer?
    var repeatEvery: Double!
    
    // Initialize
    init() {
        
        // Sample rate (samples/second) and duration (seconds)
        let fs: Double = 48000.0
        let d: Double = 0.2
        
        // How often to repeat (in seconds)
        repeatEvery = 1.0
        
        // Buffer size
        let buffSize = AVAudioFrameCount(fs*d)
        
        // Create a tone
        let a: Double = 1.0
        let f: Double = 20000.0
        let pi: Double = Double.pi
        let n = Int(buffSize)
        var x: [Float32] = Array(repeating: 0.0, count: n)
        for i in 0...Int(buffSize-1) {
            // The argument is a Double and we cast to Float32 (for a cleaner sin wave
            // compared to the argument also being Float32).
            x[i] = Float32(a*sin(2.0*pi*(f/fs)*Double(i)))
        }
        
        // Save to file
        //let writer = dataWriter()
        //writer.createFile(fileName: "tx.dat")
        //writer.writeArray(data: x)
                
        // Set up buffer to send
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: fs, channels: 2)!
        buff = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: buffSize)!
        buff.frameLength = buffSize
        buff.floatChannelData![0].initialize(from: &x, count: n)
        buff.floatChannelData![1].initialize(from: &x, count: n)
        
        // Create audio player
        player = AVAudioPlayerNode()
    }
    
    // Start transmitting in a loop
    func startLoop() {
        sendTimer = Timer.scheduledTimer(timeInterval: repeatEvery, target: self, selector: #selector(audioTx.send), userInfo: nil, repeats: true)
        sendTimer?.fire()
    }
    
    // Transmit once
    @objc func send() {
        player.scheduleBuffer(buff)
        player.play()
    }
    
    // Stop transmitting in a loop
    func stopLoop() {
        sendTimer?.invalidate()
        sendTimer = nil
        player.stop()
    }
    
}
