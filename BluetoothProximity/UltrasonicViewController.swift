//
//  UltrasonicViewController.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 5/7/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import AVFoundation
import GameplayKit

class UltrasonicViewController: UIViewController {
    
    // Objects
    var tx: audioTx!
    var rx: audioRx!
    var engine: AVAudioEngine!
    var enableTx: Bool!
    var enableRx: Bool!
    
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
        enableTx = txSwitch.isOn
        enableRx = rxSwitch.isOn
        
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
    
    // Transmit switch
    @IBOutlet weak var txSwitch: UISwitch!
    @IBAction func txSwitchChanged(_ sender: Any) {
        enableTx = txSwitch.isOn
    }
    
    // Receive switch
    @IBOutlet weak var rxSwitch: UISwitch!
    @IBAction func rxSwitchChanged(_ sender: Any) {
        enableRx = rxSwitch.isOn
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
        if enableTx {
            tx.startLoop()
        }
        if enableRx {
            rx.startLoop()
        }
        
        // Update UI
        runStopButton.setTitle("Stop", for: .normal)
        txSwitch.isEnabled = false
        rxSwitch.isEnabled = false
        
        // Update state
        isRunning = true
    }
    
    // Stops running
    func stopRun() {

        // Stop transmitter and receiver
        if enableTx {
            tx.stopLoop()
        }
        if enableRx {
            rx.stopLoop()
        }
        
        // Update UI
        runStopButton.setTitle("Run", for: .normal)
        txSwitch.isEnabled = true
        rxSwitch.isEnabled = true
        
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
        
        /*
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
        */
        
        // Create white noise, high pass filter, and normalize to +/- 1
        // This can be done more efficiently by generating the noise at baseband, then interpolating
        // (upsample + low pass filter), and finally mixing to the desired center frequency.
        let s: UInt64 = 100
        let rng = GKMersenneTwisterRandomSource(seed: s)
        let randn = GKGaussianDistribution(randomSource: rng, mean: 0, deviation: 65536.0)
        let n = Int(buffSize)
        var x: [Float32] = Array(repeating: 0.0, count: n)
        for i in 0...(n-1) {
            x[i] = Float32(Double(randn.nextInt())/65536.0)
        }
        let b: [Float32] = [-0.000236437942135332,0.000815325587435857,-0.00183656749123850,0.00322373502187833,-0.00457968516861099,0.00537189644388272,-0.00505499229413463,0.00347779908067731,-0.000994138199842880,-0.00149735453578532,0.00299215894167622,-0.00281888001320860,0.00112282019378742,0.00117742109999269,-0.00276190993327034,0.00268673229611326,-0.000919027237732912,-0.00151847017808169,0.00313502230989920,-0.00282316058926014,0.000639139330387021,0.00216118221188974,-0.00378479893826083,0.00305407445743594,-0.000213098251323078,-0.00305509803583764,0.00462083414717519,-0.00325156533384849,-0.000442882872856017,0.00423976399299556,-0.00559353103863132,0.00332987943691472,0.00143089652234904,-0.00575220869787921,0.00667203811847967,-0.00318132338188699,-0.00285718529266932,0.00765172352815033,-0.00780739875056750,0.00268031096794725,0.00487600364443114,-0.0100153958122534,0.00895157284903807,-0.00164111991850756,-0.00771526406578997,0.0129957257493104,-0.0100525527756791,-0.000208683315191778,0.0117728338217874,-0.0168823062953845,0.0110573662379157,0.00338991198315377,-0.0178761268941901,0.0223633756310119,-0.0118999586500315,-0.00913092301919785,0.0282155195419526,-0.0314611418824086,0.0125464824690390,0.0213641817308486,-0.0508192925894373,0.0527952804647337,-0.0129465536996555,-0.0650313835263956,0.158401873393614,-0.234059009950929,0.263085660805954,-0.234059009950929,0.158401873393614,-0.0650313835263956,-0.0129465536996555,0.0527952804647337,-0.0508192925894373,0.0213641817308486,0.0125464824690390,-0.0314611418824086,0.0282155195419526,-0.00913092301919785,-0.0118999586500315,0.0223633756310119,-0.0178761268941901,0.00338991198315377,0.0110573662379157,-0.0168823062953845,0.0117728338217874,-0.000208683315191778,-0.0100525527756791,0.0129957257493104,-0.00771526406578997,-0.00164111991850756,0.00895157284903807,-0.0100153958122534,0.00487600364443114,0.00268031096794725,-0.00780739875056750,0.00765172352815033,-0.00285718529266932,-0.00318132338188699,0.00667203811847967,-0.00575220869787921,0.00143089652234904,0.00332987943691472,-0.00559353103863132,0.00423976399299556,-0.000442882872856017,-0.00325156533384849,0.00462083414717519,-0.00305509803583764,-0.000213098251323078,0.00305407445743594,-0.00378479893826083,0.00216118221188974,0.000639139330387021,-0.00282316058926014,0.00313502230989920,-0.00151847017808169,-0.000919027237732912,0.00268673229611326,-0.00276190993327034,0.00117742109999269,0.00112282019378742,-0.00281888001320860,0.00299215894167622,-0.00149735453578532,-0.000994138199842880,0.00347779908067731,-0.00505499229413463,0.00537189644388272,-0.00457968516861099,0.00322373502187833,-0.00183656749123850,0.000815325587435857,-0.00023643794213533]
        var y: [Float32] = Array(repeating: 0.0, count: n)
        for i in 0...(n-1) {
            for j in 0...(b.count-1) {
                if (i + j) > (n-1) {
                    break
                } else {
                    y[i] += x[i + j]*b[j]
                }
            }
        }
        x = y
        let m = Float32(x.max()!)
        for i in 0...(n-1) {
            x[i] /= m
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
        player.prepare(withFrameCount: buff.frameLength)
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
