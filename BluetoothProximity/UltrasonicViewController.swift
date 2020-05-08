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
    var rx: audioRx!
    var engine: AVAudioEngine!
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup to play and record
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("AVAudioSession failed")
            #endif
        }
        
        // Initialize
        engine = AVAudioEngine()
        tx = audioTx()
        rx = audioRx()
        rx.recorder = engine.inputNode
        isRunning = false
        
        // Connect transmitter
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

        // Start transmitter and receiver
        tx.startLoop()
        rx.startLoop()
        
        // Update UI
        runStopButton.setTitle("Stop", for: .normal)
        
        // Update state
        isRunning = true
    }
    
    // Stops running
    func stopRun() {

        // Stop transmitter and receiver
        tx.stopLoop()
        rx.stopLoop()
        
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
    
    // Writes an array of floats to file
    func writeFloatArray(data: [Float32]) {
        fileHandle.seekToEndOfFile()
        let tmp = data.withUnsafeBytes{Array($0)}
        fileHandle.write(Data(tmp))
    }
    
    // Writes an array of doubles to file
    func writeDoubleArray(data: [Double]) {
        fileHandle.seekToEndOfFile()
        let tmp = data.withUnsafeBytes{Array($0)}
        fileHandle.write(Data(tmp))
    }
    
}

// Transmitter
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
        for i in 0...(n-1) {
            // The argument is a Double and we cast to Float32 (for a cleaner signal
            // compared to the argument also being Float32).
            x[i] = Float32(a*sin(2.0*pi*(f/fs)*Double(i)))
        }
        
        // Ramp up and down
        // Duration is in seconds
        let dRamp = 2.5e-3
        let nRamp = Int(fs*dRamp)
        for i in 0...(nRamp-1) {
            x[i] *= Float32(i)/Float32(nRamp)
            x[Int(buffSize)-i-1] *= Float32(i)/Float32(nRamp)
        }
        
        // Save to file
        let writer = dataWriter()
        writer.createFile(fileName: "tx.dat")
        writer.writeFloatArray(data: x)
                
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
        
        // Send at the next 100 ms boundary
        var info = mach_timebase_info()
        guard mach_timebase_info(&info) == KERN_SUCCESS else { return }
        let currentTime = mach_absolute_time()
        let nanos = currentTime*(UInt64(info.numer)/UInt64(info.denom))
        let sendNanos = ceil(Double(nanos)/100000000.0)*100000000.0
        let sendTime = UInt64(sendNanos)*(UInt64(info.denom)/UInt64(info.numer))
        let playTime = AVAudioTime(hostTime: sendTime)
        
        #if DEBUG
        print("Scheduling send at \(Double(nanos)/1e9) for \(sendNanos/1e9)")
        #endif
        
        // Schedule and playout
        player.scheduleBuffer(buff)
        player.play(at: playTime)
    }
    
    // Stop transmitting in a loop
    func stopLoop() {
        sendTimer?.invalidate()
        sendTimer = nil
        player.stop()
    }
    
}

class audioRx {
    
    // Objects
    var recorder: AVAudioInputNode!
    var repeatEvery: Double!
    var fs: Double!
    var n: AVAudioFrameCount!
    var audioFormat: AVAudioFormat!
    var writer: dataWriter!
    
    // Initialize
    init() {
        
        // Sample rate (samples/second)
        fs = 48000.0
        
        // Number of samples per buffer
        n = 16384
        
        // Buffer format
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(fs), channels: 1)!
        
        // Initialize data writer
        writer = dataWriter()
    }
    
    // Start receiving in a loop
    func startLoop() {
        
        // Make a new file
        writer.createFile(fileName: "rx.dat")
        
        // Install a tap
        recorder.installTap(onBus: 0, bufferSize: n, format: audioFormat) { (buffer, when) in
            let buff = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
            
            // Timestamp
            var info = mach_timebase_info()
            guard mach_timebase_info(&info) == KERN_SUCCESS else { return }
            let currentTime = when.hostTime
            let nanos = Double(currentTime*(UInt64(info.numer)/UInt64(info.denom)))

            // Process
            self.processRecv(x: Array(buff), t: nanos)
        }
        
    }
    
    // Receive processing
    func processRecv(x: [Float32], t: Double) {
        
        #if DEBUG
        print("Received \(x.count) samples at \(t)")
        #endif
        
        // Save to file
        let md = [t, Double(x.count)]
        writer.writeDoubleArray(data: md)
        writer.writeFloatArray(data: x)
    }
    
    // Stop receiving in a loop
    func stopLoop() {
        recorder.removeTap(onBus: 0)
    }
    
}
