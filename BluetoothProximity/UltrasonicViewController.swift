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
import Accelerate

struct ultrasonicData {
    static var localTime: Double = 0
    static var localTimeValid: Bool = false
    
    static var remoteTime: Double = 0
    static var remoteTimeValid: Bool = false
    
    static var masterTxSamples: [Float32] = [0]
    static var slaveTxSamples: [Float32] = [0]
    
    static var sendTime: Double = 0
    static var recvSelfTime: Double = 0
    static var recvRemoteTime: Double = 0
    
    static var selfSNR: Double = 0
    static var remoteSNR: Double = 0
}

class UltrasonicViewController: UIViewController {
    
    // Objects
    var tx: audioTx!
    var rx: audioRx!
    var engine: AVAudioEngine!
    
    // Objects from the AppDelegate
    var advertiser: BluetoothAdvertiser!
    var scanner: BluetoothScanner!
    
    // Make status bar light
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get objects from the AppDelegate
        let delegate = UIApplication.shared.delegate as! AppDelegate
        advertiser = delegate.advertiser
        scanner = delegate.scanner
        
        // Initialize scanner
        scanner.logToFile = false
        scanner.runDetector = false
        
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
        isSlave = (masterSlaveControl.selectedSegmentIndex == 1)
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
        count = 0
        countLabel.text = count.description
        localStatusLabel.text = "?"
        remoteStatusLabel.text = "?"
        rangeFeetLabel.text = "?"
        rangeInchesLabel.text = "?"
        selfSNRLabel.text = "?"
        remoteSNRLabel.text = "?"
        
        // Connect transmitter
        engine.attach(tx.player)
        engine.connect(tx.player, to:engine.outputNode, format: tx.masterBuff.format)
        
        // Startup
        do {
            try engine.start()
        } catch {
            #if DEBUG
            print("AVAudioEngine failed to start")
            #endif
        }
        
        // Observers for BLE commands
        NotificationCenter.default.addObserver(self, selector: #selector(startRun), name: Notification.Name(rawValue: "ultrasonicStartRun"), object: nil)
    }
    
    // Master/slave control
    // Only the master (0) is capable of starting a run using the button
    // The slave (1) scans Bluetooth for the start/stop signals
    var isSlave: Bool!
    @IBOutlet weak var masterSlaveControl: UISegmentedControl!
    @IBAction func masterSlaveControlChanged(_ sender: Any) {
        isSlave = (masterSlaveControl.selectedSegmentIndex == 1)
        if isSlave {
            runStopButton.setTitle("Waiting...", for: .normal)
            runStopButton.isEnabled = false
            scanner.runUltrasonic = true
            scanner.setName(name: "uStart")
            scanner.startScanForService()
        } else {
            runStopButton.setTitle("Run", for: .normal)
            runStopButton.isEnabled = true
            scanner.stop()
        }
    }

    // Range stepper
    var range: Int!
    @IBOutlet weak var rangeLabel: UILabel!
    @IBOutlet weak var rangeStepper: UIStepper!
    @IBAction func rangeStepperChanged(_ sender: Any) {
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
    }
    
    // Run/stop button
    var isRunning: Bool!
    @IBOutlet weak var runStopButton: UIButton!
    @IBAction func runStopButtonPressed(_ sender: Any) {
        if !isRunning {
            startRun()
        }
    }
        
    // Starts running
    @objc func startRun() {
        
        // Only run if we're not already running
        if isRunning {
            return
        }
        
        // Update state
        isRunning = true
        
        // Update UI
        runStopButton.setTitle("Running...", for: .normal)
        runStopButton.isEnabled = false
        rangeStepper.isEnabled = false
        masterSlaveControl.isEnabled = false
        
        // Mark data as invalid
        ultrasonicData.localTimeValid = false
        ultrasonicData.remoteTimeValid = false
        
        // If we are the master, tell the slave to start
        // If we are the slave, stop scanning
        if !isSlave {
            advertiser.setName(name: "uStart")
            advertiser.start()
        } else {
            scanner.stop()
        }
        
        // Start scanning for measurement data
        scanner.runUltrasonic = true
        scanner.setName(name: "uMeas")
        scanner.startScanForService()
        
        // Run transmitter and receiver
        tx.run(isSlave: isSlave, range: range, count: count)
        rx.run(isSlave: isSlave, range: range, count: count)
                
        // Stop running after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.stopRun()
        })
    }
    
    // Stops running
    @objc func stopRun() {
        
        // Advertise our measurement (if we're master, stop advertising first)
        // The measurement is rounded to the nearest nanosecond, since that's
        // plenty for precision, and using a longer advertising name seemed to
        // cause unstable BLE behavior.
        if !isSlave {
            advertiser.stop()
        }
        let t = Int64(round(ultrasonicData.localTime))
        let m = "uMeas" + t.description
        advertiser.setName(name: m)
        advertiser.start()
                
        // Wait 500 ms before continuing
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
            
            // Stop BLE activity. If we're the slave, return to search for the start signal
            self.advertiser.stop()
            self.scanner.stop()
            if self.isSlave {
                self.scanner.runUltrasonic = true
                self.scanner.setName(name: "uStart")
                self.scanner.startScanForService()
            }
            
            // Compute range
            self.twoWayRanging()
            
            // Update run counter
            self.count += 1
            self.countLabel.text = self.count.description
            
            // Update UI
            if self.isSlave {
                self.runStopButton.setTitle("Waiting...", for: .normal)
            } else {
                self.runStopButton.isEnabled = true
                self.runStopButton.setTitle("Run", for: .normal)
            }
            self.rangeStepper.isEnabled = true
            self.masterSlaveControl.isEnabled = true
            
            // Update state
            self.isRunning = false
        })
    }
    
    // Stop any run when we leave the tab
    override func viewWillDisappear(_ animated: Bool) {
        if isRunning {
            stopRun()
        }
        advertiser.setName(name: "BlueProxTx")
        if isSlave {
            scanner.stop()
        }
        scanner.runUltrasonic = false
        scanner.setName(name: "BlueProxTx")
    }
    
    // Get back in a good state if we're returning to this tab
    override func viewDidAppear(_ animated: Bool) {
        if isSlave {
            scanner.runUltrasonic = true
            scanner.setName(name: "uStart")
            scanner.startScanForService()
        }
    }
    
    // Run counter
    var count: Int!
    @IBOutlet weak var countLabel: UILabel!
    
    // Two-way ranging processing
    @IBOutlet weak var localStatusLabel: UILabel!
    @IBOutlet weak var remoteStatusLabel: UILabel!
    @IBOutlet weak var rangeFeetLabel: UILabel!
    @IBOutlet weak var rangeInchesLabel: UILabel!
    @IBOutlet weak var selfSNRLabel: UILabel!
    @IBOutlet weak var remoteSNRLabel: UILabel!
    func twoWayRanging() {
                
        // Display local/remote status
        if !ultrasonicData.localTimeValid {
            localStatusLabel.text = "Error"
            localStatusLabel.textColor = UIColor.red
        } else {
            localStatusLabel.text = "OK"
            localStatusLabel.textColor = UIColor.green
        }
        if !ultrasonicData.remoteTimeValid {
            remoteStatusLabel.text = "Error"
            remoteStatusLabel.textColor = UIColor.red
        } else {
            remoteStatusLabel.text = "OK"
            remoteStatusLabel.textColor = UIColor.green
        }
        
        // Display self/remote SNR measurements
        selfSNRLabel.text = String(format: "%.1f", ultrasonicData.selfSNR)
        remoteSNRLabel.text = String(format: "%.1f", ultrasonicData.remoteSNR)
        
        // If either data is not valid, quit
        if !ultrasonicData.localTimeValid || !ultrasonicData.remoteTimeValid {
            rangeFeetLabel.text = "?"
            rangeInchesLabel.text = "?"
            return
        }
        
        // Display range in feet and inches
        var rangeFeetFrac = (346.0/2.0)*(ultrasonicData.localTime + ultrasonicData.remoteTime)*3.28084/1e9
        rangeFeetFrac = abs(rangeFeetFrac)
        var rangeFeet = Int(rangeFeetFrac)
        var rangeInchesFrac = (rangeFeetFrac - Double(rangeFeet))*12
        rangeInchesFrac.round(.toNearestOrAwayFromZero)
        var rangeInches = Int(rangeInchesFrac)
        if rangeInches == 12 {
            rangeFeet += 1
            rangeInches = 0
        }
        rangeFeetLabel.text = rangeFeet.description
        rangeInchesLabel.text = rangeInches.description
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

// Crosscorrelation to match MATLAB routine
func xcorr(a: [Float32], b: [Float32]) -> ([Float32], [Int]) {
    
    // Pad "a" (longer input) with zeros based on the length of "b"
    var aPadded = a
    for _ in 0...(b.count-2) {
        aPadded.insert(0.0, at: 0)
    }
    for _ in 0...(b.count-1) {
        aPadded.insert(0.0, at: aPadded.endIndex)
    }
    
    // Crosscorrelation
    var c: [Float32]
    if #available(iOS 13.0, *) {
        c = vDSP.correlate(aPadded, withKernel: b)
    } else {
        #if DEBUG
        print("vDSP.correlate is not available")
        #endif
        c = [-1]
    }
    
    // Lags
    let lStart: Int = 0 - (b.count - 1)
    let lEnd: Int = a.count + b.count - 2 - (b.count - 1)
    let l: [Int] = Array(lStart...lEnd)
    
    // All done
    return (c, l)
}

// Transmitter
class audioTx {
    
    // Objects
    var masterBuff: AVAudioPCMBuffer!
    var slaveBuff: AVAudioPCMBuffer!
    var player: AVAudioPlayerNode!
    var writer: dataWriter!
    
    // Initialize
    init() {
        
        // Sample rate (samples/second(
        let fs: Double = 48000.0
        
        // Transmit waveform duration (seconds)
        let d: Double = 0.1
                
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
        
        // NOTE: signal to transmit could be generated more efficiently...for instance,
        // create white noise with ~6 kHz bandwidth at baseband, then upsample and
        // frequency convert to 21 kHz.
        
        // High pass filter taps
        // Transition band is 17-18 kHz (everything above 18 kHz is passed)
        let b: [Float32] = [-0.000236437942135332,0.000815325587435857,-0.00183656749123850,0.00322373502187833,-0.00457968516861099,0.00537189644388272,-0.00505499229413463,0.00347779908067731,-0.000994138199842880,-0.00149735453578532,0.00299215894167622,-0.00281888001320860,0.00112282019378742,0.00117742109999269,-0.00276190993327034,0.00268673229611326,-0.000919027237732912,-0.00151847017808169,0.00313502230989920,-0.00282316058926014,0.000639139330387021,0.00216118221188974,-0.00378479893826083,0.00305407445743594,-0.000213098251323078,-0.00305509803583764,0.00462083414717519,-0.00325156533384849,-0.000442882872856017,0.00423976399299556,-0.00559353103863132,0.00332987943691472,0.00143089652234904,-0.00575220869787921,0.00667203811847967,-0.00318132338188699,-0.00285718529266932,0.00765172352815033,-0.00780739875056750,0.00268031096794725,0.00487600364443114,-0.0100153958122534,0.00895157284903807,-0.00164111991850756,-0.00771526406578997,0.0129957257493104,-0.0100525527756791,-0.000208683315191778,0.0117728338217874,-0.0168823062953845,0.0110573662379157,0.00338991198315377,-0.0178761268941901,0.0223633756310119,-0.0118999586500315,-0.00913092301919785,0.0282155195419526,-0.0314611418824086,0.0125464824690390,0.0213641817308486,-0.0508192925894373,0.0527952804647337,-0.0129465536996555,-0.0650313835263956,0.158401873393614,-0.234059009950929,0.263085660805954,-0.234059009950929,0.158401873393614,-0.0650313835263956,-0.0129465536996555,0.0527952804647337,-0.0508192925894373,0.0213641817308486,0.0125464824690390,-0.0314611418824086,0.0282155195419526,-0.00913092301919785,-0.0118999586500315,0.0223633756310119,-0.0178761268941901,0.00338991198315377,0.0110573662379157,-0.0168823062953845,0.0117728338217874,-0.000208683315191778,-0.0100525527756791,0.0129957257493104,-0.00771526406578997,-0.00164111991850756,0.00895157284903807,-0.0100153958122534,0.00487600364443114,0.00268031096794725,-0.00780739875056750,0.00765172352815033,-0.00285718529266932,-0.00318132338188699,0.00667203811847967,-0.00575220869787921,0.00143089652234904,0.00332987943691472,-0.00559353103863132,0.00423976399299556,-0.000442882872856017,-0.00325156533384849,0.00462083414717519,-0.00305509803583764,-0.000213098251323078,0.00305407445743594,-0.00378479893826083,0.00216118221188974,0.000639139330387021,-0.00282316058926014,0.00313502230989920,-0.00151847017808169,-0.000919027237732912,0.00268673229611326,-0.00276190993327034,0.00117742109999269,0.00112282019378742,-0.00281888001320860,0.00299215894167622,-0.00149735453578532,-0.000994138199842880,0.00347779908067731,-0.00505499229413463,0.00537189644388272,-0.00457968516861099,0.00322373502187833,-0.00183656749123850,0.000815325587435857,-0.00023643794213533]
        
        // -------------------------------------------------------------------------------------
        // Master TX waveform
        // -------------------------------------------------------------------------------------
        
        // Random number generator seed based on UDID
        //let devStr = UIDevice.current.identifierForVendor?.uuidString
        //let devSeed: UInt64 = strHash(devStr!)
        
        // Create white noise (as integers, then scaled to floats)
        let masterSeed: UInt64 = strHash("master123")
        let masterRng = GKMersenneTwisterRandomSource(seed: masterSeed)
        let stdDev = Float32(65536.0)
        let masterRandn = GKGaussianDistribution(randomSource: masterRng, mean: 0, deviation: stdDev)
        let n = Int(buffSize)
        let n_pad = b.count
        var x: [Float32] = Array(repeating: 0.0, count: (n + n_pad))
        for i in 0...(n-1) {
            x[i] = Float32(masterRandn.nextInt())/stdDev
        }
        
        // High pass filter
        if #available(iOS 13.0, *) {
            ultrasonicData.masterTxSamples = vDSP.convolve(x, withKernel: b)
        } else {
            // Fallback on earlier versions
            #if DEBUG
            print("vDSP.convolve is not available")
            #endif
        }

        // Normalize to +/- 1
        var m = Float32(ultrasonicData.masterTxSamples.max()!)
        ultrasonicData.masterTxSamples.enumerated().forEach { i, v in
            ultrasonicData.masterTxSamples[i] = v/m
        }
        
        // Ramp up and down
        // Duration is in seconds
        let dRamp = 2.5e-3
        let nRamp = Int(fs*dRamp)
        for i in 0...(nRamp-1) {
            ultrasonicData.masterTxSamples[i] *= Float32(i)/Float32(nRamp)
            ultrasonicData.masterTxSamples[Int(buffSize)-i-1] *= Float32(i)/Float32(nRamp)
        }
        
        // Set up buffer to send
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: fs, channels: 1)!
        masterBuff = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: buffSize)!
        masterBuff.frameLength = buffSize
        masterBuff.floatChannelData![0].initialize(from: &ultrasonicData.masterTxSamples, count: n)
        
        // -------------------------------------------------------------------------------------
        // Slave TX waveform
        // -------------------------------------------------------------------------------------
        
        // Create white noise (as integers, then scaled to floats)
        let slaveSeed: UInt64 = strHash("slave456")
        let slaveRng = GKMersenneTwisterRandomSource(seed: slaveSeed)
        let slaveRandn = GKGaussianDistribution(randomSource: slaveRng, mean: 0, deviation: stdDev)
        x = Array(repeating: 0.0, count: (n + n_pad))
        for i in 0...(n-1) {
            x[i] = Float32(slaveRandn.nextInt())/stdDev
        }
        
        // High pass filter
        if #available(iOS 13.0, *) {
            ultrasonicData.slaveTxSamples = vDSP.convolve(x, withKernel: b)
        } else {
            // Fallback on earlier versions
            #if DEBUG
            print("vDSP.convolve is not available")
            #endif
        }

        // Normalize to +/- 1
        m = Float32(ultrasonicData.slaveTxSamples.max()!)
        ultrasonicData.slaveTxSamples.enumerated().forEach { i, v in
            ultrasonicData.slaveTxSamples[i] = v/m
        }
        
        // Ramp up and down
        for i in 0...(nRamp-1) {
            ultrasonicData.slaveTxSamples[i] *= Float32(i)/Float32(nRamp)
            ultrasonicData.slaveTxSamples[Int(buffSize)-i-1] *= Float32(i)/Float32(nRamp)
        }
        
        // Set up buffer to send
        slaveBuff = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: buffSize)!
        slaveBuff.frameLength = buffSize
        slaveBuff.floatChannelData![0].initialize(from: &ultrasonicData.slaveTxSamples, count: n)
        
        // -------------------------------------------------------------------------------------
        // Finish audio setup
        // -------------------------------------------------------------------------------------
        
        // Create audio player
        player = AVAudioPlayerNode()
        
        // Initialize data writer
        writer = dataWriter()
    }
    
    // Hash string to uint64
    // Reference: https://stackoverflow.com/questions/52440502/string-hashvalue-not-unique-after-reset-app-when-build-in-xcode-10
    func strHash(_ str: String) -> UInt64 {
        var result = UInt64 (5381)
        let buf = [UInt8](str.utf8)
        for b in buf {
            result = 127 * (result & 0x00ffffffffffffff) + UInt64(b)
        }
        return result
    }
    
    // Main transmit routine
    @objc func run(isSlave: Bool, range: Int, count: Int) {
        
        // Make a new file
        var id = "master"
        if isSlave {
            id = "slave"
        }
        let txFile = id + "_tx_rng_" + range.description + "_cnt_" + count.description + ".dat"
        writer.createFile(fileName: txFile)
        
        // Save samples to file
        if isSlave {
            writer.writeDoubleArray(data: [Double(ultrasonicData.slaveTxSamples.count)])
            writer.writeFloatArray(data: ultrasonicData.slaveTxSamples)
        } else {
            writer.writeDoubleArray(data: [Double(ultrasonicData.masterTxSamples.count)])
            writer.writeFloatArray(data: ultrasonicData.masterTxSamples)
        }
                
        // Master sends 50 ms from now, slave 250 ms from now
        var info = mach_timebase_info()
        guard mach_timebase_info(&info) == KERN_SUCCESS else { return }
        let currentTime = mach_absolute_time()
        let nanos = currentTime*UInt64(info.numer)/UInt64(info.denom)
        var sendNanos: Double
        if isSlave {
            sendNanos = Double(nanos) + 250000000.0
        } else {
            sendNanos = Double(nanos) + 50000000.0
        }
        let sendTime = UInt64(sendNanos)*UInt64(info.denom)/UInt64(info.numer)
        let sendAvTime = AVAudioTime(hostTime: sendTime)
        
        // Save time
        ultrasonicData.sendTime = sendNanos
        writer.writeDoubleArray(data: [Double(nanos), sendNanos])
        
        #if DEBUG
        //print("Scheduling send at \(Double(nanos)/1e9) for \(sendNanos/1e9)")
        #endif
        
        // Schedule and playout
        player.stop()
        if isSlave {
            player.scheduleBuffer(slaveBuff)
            player.prepare(withFrameCount: slaveBuff.frameLength)
        } else {
            player.scheduleBuffer(masterBuff)
            player.prepare(withFrameCount: masterBuff.frameLength)
        }
        player.play(at: sendAvTime)
    }
    
}

class audioRx {
    
    // Objects
    var recorder: AVAudioInputNode!
    var fs: Double!
    var txN: Int!
    var n: AVAudioFrameCount!
    var audioFormat: AVAudioFormat!
    var writer: dataWriter!
    
    // Initialize
    init() {
        
        // Sample rate (samples/second)
        fs = 48000.0
                
        // Transmit waveform duration (seconds and samples
        let d = 100e-3
        txN = Int(fs*d)
        
        // Number of samples per receive buffer
        n = 19200
        
        // Buffer format
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(fs), channels: 1)!
        
        // Initialize data writer
        writer = dataWriter()
    }
    
    // Main receive routine
    func run(isSlave: Bool, range: Int, count: Int) {
        
        // Make a new file
        var id = "master"
        if isSlave {
            id = "slave"
        }
        let rxFile = id + "_rx_rng_" + range.description + "_cnt_" + count.description + ".dat"
        writer.createFile(fileName: rxFile)
        
        // Install a tap
        recorder.installTap(onBus: 0, bufferSize: n, format: audioFormat) { (buffer, when) in
            let buff = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
            
            // Timestamp this buffer
            var info = mach_timebase_info()
            guard mach_timebase_info(&info) == KERN_SUCCESS else { return }
            let currentTime = when.hostTime
            let nanos = Double(currentTime*UInt64(info.numer)/UInt64(info.denom))
            
            // Stop receiving data
            self.recorder.removeTap(onBus: 0)

            // Process data
            self.processData(isSlave: isSlave, x: Array(buff), t: nanos)
        }
        
    }
    
    // Receiver processing
    func processData(isSlave: Bool, x: [Float32], t: Double) {
        
        #if DEBUG
        //print("Received \(x.count) samples at \(t)")
        #endif
        
        // Save to file
        let md = [t, Double(x.count)]
        writer.writeDoubleArray(data: md)
        writer.writeFloatArray(data: x)
        
        // Crosscorrelation with self
        var y: [Float32]
        var yLags: [Int]
        if isSlave {
            (y, yLags) = xcorr(a: x, b: ultrasonicData.slaveTxSamples)
        } else {
            (y, yLags) = xcorr(a: x, b: ultrasonicData.masterTxSamples)
        }
        y = y.map(abs)
        var selfIdx: UInt = 0
        var yMax: Float32 = 1e-9
        if #available(iOS 13.0, *) {
            (selfIdx, yMax) = vDSP.indexOfMaximum(y)
        } else {
            #if DEBUG
            print("vDSP.correlate is not available")
            #endif
        }
        let tSelf = Double(yLags[Int(selfIdx)])*(1.0/fs)*1e9
        
        // Loopback delay
        let tDelta = (tSelf + t) - ultrasonicData.sendTime
        
        // SNR for self received
        let noise = y.prefix(Int(selfIdx) - txN)
        let noiseMean = noise.reduce(0, +)/Float32(noise.count)
        ultrasonicData.selfSNR = 10*log10(Double(yMax/noiseMean))
        
        // Crosscorrelation with remote, and remove self transmit signal
        var z: [Float32]
        var zLags: [Int]
        if isSlave {
            
            // Slave with master
            (z, zLags) = xcorr(a: x, b: ultrasonicData.masterTxSamples)
            
            // Slave transmits second
            let rmIdx = Int(selfIdx) - txN
            z = Array(z.prefix(rmIdx))
            zLags = Array(zLags.prefix(rmIdx))
            
        } else {
            
            // Master with slave (master transmits first)
            (z, zLags) = xcorr(a: x, b: ultrasonicData.slaveTxSamples)
            
            // Master transmits first
            let rmIdx = Int(selfIdx) + txN
            z.removeFirst(rmIdx)
            zLags.removeFirst(rmIdx)
            
        }
        z = z.map(abs)
        var remoteIdx: UInt = 0
        var zMax: Float32 = 1e-9
        if #available(iOS 13.0, *) {
            (remoteIdx, zMax) = vDSP.indexOfMaximum(z)
        } else {
            #if DEBUG
            print("vDSP.correlate is not available")
            #endif
        }
        let tRemote = Double(zLags[Int(remoteIdx)])*(1.0/fs)*1e9
        
        // SNR for remote received (uses noise from before)
        ultrasonicData.remoteSNR = 10*log10(Double(zMax/noiseMean))
                
        // Compute timing measurement and mark as valid
        if !ultrasonicData.localTimeValid {
            ultrasonicData.localTime = (tRemote + t) - ultrasonicData.sendTime - tDelta
            ultrasonicData.localTimeValid = true
        }
    }
    
}
