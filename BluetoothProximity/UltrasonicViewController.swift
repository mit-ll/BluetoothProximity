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
    
    static var leaderTxSamples: [Float32] = [0]
    static var followerTxSamples: [Float32] = [0]
    
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
        
        // Warn if no vDSP (and disable the UI)
        if #available(iOS 13.0, *) {
            #if DEBUG
            print("vDSP is available")
            #endif
        } else {
            leaderFollowerControl.isEnabled = false
            rangeStepper.isEnabled = false
            runStopButton.isEnabled = false
            runStopButton.setTitle("Disabled", for: .normal)
            let alert = UIAlertController(title: "Warning", message: "Please update to iOS 13.0 or higher (this app requires vDSP to function)", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction!) in
            }))
            present(alert, animated: true, completion: nil)
        }
        
        // Initialize
        engine = AVAudioEngine()
        tx = audioTx()
        rx = audioRx()
        rx.recorder = engine.inputNode
        isRunning = false
        isFollower = (leaderFollowerControl.selectedSegmentIndex == 1)
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
        engine.connect(tx.player, to:engine.outputNode, format: tx.leaderBuff.format)
        
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
    
    // Leader/follower control
    // Only the leader (0) is capable of starting a run using the button
    // The follower (1) scans Bluetooth for the start/stop signals
    var isFollower: Bool!
    @IBOutlet weak var leaderFollowerControl: UISegmentedControl!
    @IBAction func leaderFollowerControlChanged(_ sender: Any) {
        isFollower = (leaderFollowerControl.selectedSegmentIndex == 1)
        if isFollower {
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
        leaderFollowerControl.isEnabled = false
        
        // Mark data as invalid
        ultrasonicData.localTimeValid = false
        ultrasonicData.remoteTimeValid = false
        
        // If we are the leader, tell the follower to start
        // If we are the follower, stop scanning
        if !isFollower {
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
        tx.run(isFollower: isFollower, range: range, count: count)
        rx.run(isFollower: isFollower, range: range, count: count)
                
        // Stop running after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.stopRun()
        })
    }
    
    // Stops running
    @objc func stopRun() {
        
        // Advertise our measurement (if we're the leader, stop advertising first)
        // The measurement is rounded to the nearest nanosecond, since that's
        // plenty for precision, and using a longer advertising name seemed to
        // cause unstable BLE behavior.
        if !isFollower {
            advertiser.stop()
        }
        let t = Int64(round(ultrasonicData.localTime))
        let m = "uMeas" + t.description
        advertiser.setName(name: m)
        advertiser.start()
                
        // Wait 500 ms before continuing
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
            
            // Stop BLE activity. If we're the follower, return to search for the start signal
            self.advertiser.stop()
            self.scanner.stop()
            if self.isFollower {
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
            if self.isFollower {
                self.runStopButton.setTitle("Waiting...", for: .normal)
            } else {
                self.runStopButton.isEnabled = true
                self.runStopButton.setTitle("Run", for: .normal)
            }
            self.rangeStepper.isEnabled = true
            self.leaderFollowerControl.isEnabled = true
            
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
        if isFollower {
            scanner.stop()
        }
        scanner.runUltrasonic = false
        scanner.setName(name: "BlueProxTx")
    }
    
    // Get back in a good state if we're returning to this tab
    override func viewDidAppear(_ animated: Bool) {
        if isFollower {
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
    var c: [Float32] = [-1]
    if #available(iOS 13.0, *) {
        c = vDSP.correlate(aPadded, withKernel: b)
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
    var leaderBuff: AVAudioPCMBuffer!
    var followerBuff: AVAudioPCMBuffer!
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
        
        // The TX signal design includes random noise (500 Hz bandwidth) with an embedded
        // tone. This is generated at the full sample rate just to demonstrate the concept.
        // It could be generated more efficiently by creating white noise at baseband with
        // 500 Hz bandwidth and a DC offset, then upsampling and upconverting to 18.5 kHz
        // center frequency.
        
        // Tone at 18.5 kHz center frequency
        let a: Double = 1.0
        let f: Double = 18500.0
        let pi: Double = Double.pi
        let n = Int(buffSize)
        var xTone: [Float32] = Array(repeating: 0.0, count: n)
        for i in 0...(n-1) {
            // The argument is a Double and we cast to Float32 (for a cleaner signal
            // compared to the argument also being Float32).
            xTone[i] = Float32(a*sin(2.0*pi*(f/fs)*Double(i)))
        }
        
        // Bandpass filter taps for filtering the noise
        // - 500 Hz passband from 18250 to 18750 Hz
        // - 750 Hz roll-off on each side
        // - 0.1 dB passband attenuation
        // - 60 dB stopband attenuation
        let b: [Float32] = [0.000559307366202422,-0.000105044593036754,-6.55571494318232e-06,0.000141691999104459,-0.000223745641658177,0.000205039133486913,-9.90960578661879e-05,-2.66388272932464e-05,9.63183410592764e-05,-7.97356516811218e-05,1.44238549832750e-05,2.34524996522595e-05,1.75972426974039e-05,-0.000110334583565090,0.000153609162744435,-4.22400975052437e-05,-0.000235549502790688,0.000546527681056577,-0.000660412612870682,0.000391500026201301,0.000244315858399088,-0.000968103710774260,0.00134298722721669,-0.00101864079878823,-1.39574432516265e-05,0.00132507957501229,-0.00220607456892111,0.00204191760357605,-0.000704739040361861,-0.00127222733692754,0.00288802701563471,-0.00318003663049466,0.00178777794414067,0.000753151944852490,-0.00319819197526605,0.00421290436176630,-0.00311278816238326,0.000307541712589311,0.00283506822491854,-0.00467626972063451,0.00419209627961180,-0.00156434319428073,-0.00187640601388951,0.00435179053285182,-0.00460270839283152,0.00257545321660017,0.000570963493053750,-0.00314395223938067,0.00388439916029065,-0.00264820153757475,0.000400415635369738,0.00145806659534441,-0.00199402282037662,0.00129127254717330,-0.000288043875674448,1.38310879535348e-05,-0.000752895295806168,0.00174206117775014,-0.00167845724212540,-0.000243709048613494,0.00346946038226968,-0.00607768596224653,0.00582018370825694,-0.00168411005406015,-0.00500845449816814,0.0108262137700717,-0.0119196757192622,0.00637818332946471,0.00412674150747766,-0.0145883818687631,0.0189992053664750,-0.0137155733009049,-1.00155418716806e-06,0.0159058814105881,-0.0255690275875856,0.0228257049170098,-0.00753523531195881,-0.0135844474193129,0.0298613905000926,-0.0320915444627649,0.0177076439522893,0.00719753495908179,-0.0303947367428876,0.0395829656400526,-0.0289597773449750,0.00276129381865902,0.0263456442232062,-0.0434655535893654,0.0391965148550472,-0.0148192323173153,-0.0179283443414944,0.0425840157971701,-0.0463684935139043,0.0268983928136983,0.00635494407549044,-0.0367491283669605,0.0489387111970243,-0.0367491283669605,0.00635494407549044,0.0268983928136983,-0.0463684935139043,0.0425840157971701,-0.0179283443414944,-0.0148192323173153,0.0391965148550472,-0.0434655535893654,0.0263456442232062,0.00276129381865902,-0.0289597773449750,0.0395829656400526,-0.0303947367428876,0.00719753495908179,0.0177076439522893,-0.0320915444627649,0.0298613905000926,-0.0135844474193129,-0.00753523531195881,0.0228257049170098,-0.0255690275875856,0.0159058814105881,-1.00155418716806e-06,-0.0137155733009049,0.0189992053664750,-0.0145883818687631,0.00412674150747766,0.00637818332946471,-0.0119196757192622,0.0108262137700717,-0.00500845449816814,-0.00168411005406015,0.00582018370825694,-0.00607768596224653,0.00346946038226968,-0.000243709048613494,-0.00167845724212540,0.00174206117775014,-0.000752895295806168,1.38310879535348e-05,-0.000288043875674448,0.00129127254717330,-0.00199402282037662,0.00145806659534441,0.000400415635369738,-0.00264820153757475,0.00388439916029065,-0.00314395223938067,0.000570963493053750,0.00257545321660017,-0.00460270839283152,0.00435179053285182,-0.00187640601388951,-0.00156434319428073,0.00419209627961180,-0.00467626972063451,0.00283506822491854,0.000307541712589311,-0.00311278816238326,0.00421290436176630,-0.00319819197526605,0.000753151944852490,0.00178777794414067,-0.00318003663049466,0.00288802701563471,-0.00127222733692754,-0.000704739040361861,0.00204191760357605,-0.00220607456892111,0.00132507957501229,-1.39574432516265e-05,-0.00101864079878823,0.00134298722721669,-0.000968103710774260,0.000244315858399088,0.000391500026201301,-0.000660412612870682,0.000546527681056577,-0.000235549502790688,-4.22400975052437e-05,0.000153609162744435,-0.000110334583565090,1.75972426974039e-05,2.34524996522595e-05,1.44238549832750e-05,-7.97356516811218e-05,9.63183410592764e-05,-2.66388272932464e-05,-9.90960578661879e-05,0.000205039133486913,-0.000223745641658177,0.000141691999104459,-6.55571494318232e-06,-0.000105044593036754,0.000559307366202422]
        
        // -------------------------------------------------------------------------------------
        // Leader TX waveform
        // -------------------------------------------------------------------------------------
        
        // Random number generator seed based on UDID
        //let devStr = UIDevice.current.identifierForVendor?.uuidString
        //let devSeed: UInt64 = strHash(devStr!)
        
        // Create white noise (as integers, then scaled to floats)
        // The seed could be generated from the BLE UUID
        let leaderSeed: UInt64 = strHash("leader123")
        let leaderRng = GKMersenneTwisterRandomSource(seed: leaderSeed)
        let stdDev = Float32(65536.0)
        let leaderRandn = GKGaussianDistribution(randomSource: leaderRng, mean: 0, deviation: stdDev)
        let n_pad = b.count
        var xNoise: [Float32] = Array(repeating: 0.0, count: (n + n_pad))
        for i in 0...(n-1) {
            xNoise[i] = Float32(leaderRandn.nextInt())/stdDev
        }
        
        // High pass filter
        if #available(iOS 13.0, *) {
            ultrasonicData.leaderTxSamples = vDSP.convolve(xNoise, withKernel: b)
        }
        
        // Embed a low power tone
        ultrasonicData.leaderTxSamples.enumerated().forEach { i, v in
            ultrasonicData.leaderTxSamples[i] = v + 0.1*xTone[i]
        }

        // Normalize to +/- 1
        var m = Float32(ultrasonicData.leaderTxSamples.max()!)
        ultrasonicData.leaderTxSamples.enumerated().forEach { i, v in
            ultrasonicData.leaderTxSamples[i] = v/m
        }
        
        // Ramp up and down
        // Duration is in seconds
        let dRamp = 2.5e-3
        let nRamp = Int(fs*dRamp)
        for i in 0...(nRamp-1) {
            ultrasonicData.leaderTxSamples[i] *= Float32(i)/Float32(nRamp)
            ultrasonicData.leaderTxSamples[Int(buffSize)-i-1] *= Float32(i)/Float32(nRamp)
        }
        
        // Set up buffer to send
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: fs, channels: 1)!
        leaderBuff = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: buffSize)!
        leaderBuff.frameLength = buffSize
        leaderBuff.floatChannelData![0].initialize(from: &ultrasonicData.leaderTxSamples, count: n)
        
        // -------------------------------------------------------------------------------------
        // Follower TX waveform
        // -------------------------------------------------------------------------------------
        
        // Create white noise (as integers, then scaled to floats)
        // The seed could be generated from the BLE UUID
        let followerSeed: UInt64 = strHash("follower456")
        let followerRng = GKMersenneTwisterRandomSource(seed: followerSeed)
        let followerRandn = GKGaussianDistribution(randomSource: followerRng, mean: 0, deviation: stdDev)
        xNoise = Array(repeating: 0.0, count: (n + n_pad))
        for i in 0...(n-1) {
            xNoise[i] = Float32(followerRandn.nextInt())/stdDev
        }
        
        // High pass filter
        if #available(iOS 13.0, *) {
            ultrasonicData.followerTxSamples = vDSP.convolve(xNoise, withKernel: b)
        }
        
        // Embed a low power tone
        ultrasonicData.followerTxSamples.enumerated().forEach { i, v in
            ultrasonicData.followerTxSamples[i] = v + 0.1*xTone[i]
        }

        // Normalize to +/- 1
        m = Float32(ultrasonicData.followerTxSamples.max()!)
        ultrasonicData.followerTxSamples.enumerated().forEach { i, v in
            ultrasonicData.followerTxSamples[i] = v/m
        }
        
        // Ramp up and down
        for i in 0...(nRamp-1) {
            ultrasonicData.followerTxSamples[i] *= Float32(i)/Float32(nRamp)
            ultrasonicData.followerTxSamples[Int(buffSize)-i-1] *= Float32(i)/Float32(nRamp)
        }
        
        // Set up buffer to send
        followerBuff = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: buffSize)!
        followerBuff.frameLength = buffSize
        followerBuff.floatChannelData![0].initialize(from: &ultrasonicData.followerTxSamples, count: n)
        
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
    @objc func run(isFollower: Bool, range: Int, count: Int) {
        
        // Make a new file
        var id = "leader"
        if isFollower {
            id = "follower"
        }
        let txFile = id + "_tx_rng_" + range.description + "_cnt_" + count.description + ".dat"
        writer.createFile(fileName: txFile)
        
        // Save samples to file
        if isFollower {
            writer.writeDoubleArray(data: [Double(ultrasonicData.followerTxSamples.count)])
            writer.writeFloatArray(data: ultrasonicData.followerTxSamples)
        } else {
            writer.writeDoubleArray(data: [Double(ultrasonicData.leaderTxSamples.count)])
            writer.writeFloatArray(data: ultrasonicData.leaderTxSamples)
        }
                
        // Leader sends 50 ms from now, follower 250 ms from now
        var info = mach_timebase_info()
        guard mach_timebase_info(&info) == KERN_SUCCESS else { return }
        let currentTime = mach_absolute_time()
        let nanos = currentTime*UInt64(info.numer)/UInt64(info.denom)
        var sendNanos: Double
        if isFollower {
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
        if isFollower {
            player.scheduleBuffer(followerBuff)
            player.prepare(withFrameCount: followerBuff.frameLength)
        } else {
            player.scheduleBuffer(leaderBuff)
            player.prepare(withFrameCount: leaderBuff.frameLength)
        }
        player.play(at: sendAvTime)
    }
    
}

class audioRx {
    
    // Objects
    var recorder: AVAudioInputNode!
    var fs: Double!
    var txN: Int!
    var noiseN: Int!
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
        
        // Number of samples to use for noise estimate
        let dNoise = 20e-3
        noiseN = Int(fs*dNoise)
        
        // Number of samples per receive buffer
        n = 19200
        
        // Buffer format
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(fs), channels: 1)!
        
        // Initialize data writer
        writer = dataWriter()
    }
    
    // Main receive routine
    func run(isFollower: Bool, range: Int, count: Int) {
        
        // Make a new file
        var id = "leader"
        if isFollower {
            id = "follower"
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
            self.processData(isFollower: isFollower, x: Array(buff), t: nanos)
        }
        
    }
    
    // Receiver processing
    func processData(isFollower: Bool, x: [Float32], t: Double) {
        
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
        if isFollower {
            (y, yLags) = xcorr(a: x, b: ultrasonicData.followerTxSamples)
        } else {
            (y, yLags) = xcorr(a: x, b: ultrasonicData.leaderTxSamples)
        }
        if #available(iOS 13.0, *) {
            y = vDSP.square(y)
        }
        
        // Find direct path as the maximum (since TX/RX is on the same device)
        var selfIdx: UInt = 0
        var yMax: Float32 = 1e-9
        if #available(iOS 13.0, *) {
            (selfIdx, yMax) = vDSP.indexOfMaximum(y)
        }
        let tSelf = Double(yLags[Int(selfIdx)])*(1.0/fs)*1e9
        
        // Loopback delay
        let tDelta = (tSelf + t) - ultrasonicData.sendTime
        
        // SNR for self received (uses noise from beginning)
        let noise = y.prefix(noiseN)
        let noiseMean = noise.reduce(0, +)/Float32(noise.count)
        ultrasonicData.selfSNR = 10*log10(Double(yMax/noiseMean))
        
        // Crosscorrelation with remote, and remove self transmit signal
        var z: [Float32]
        var zLags: [Int]
        if isFollower {
            
            // With leader TX signal
            (z, zLags) = xcorr(a: x, b: ultrasonicData.leaderTxSamples)
            
            // Follower transmits second
            let rmIdx = Int(selfIdx) - txN
            z = Array(z.prefix(rmIdx))
            zLags = Array(zLags.prefix(rmIdx))
            
        } else {
            
            // With follower TX signal
            (z, zLags) = xcorr(a: x, b: ultrasonicData.followerTxSamples)
            
            // Leader transmits first
            let rmIdx = Int(selfIdx) + txN
            z.removeFirst(rmIdx)
            zLags.removeFirst(rmIdx)
            
        }
        if #available(iOS 13.0, *) {
            z = vDSP.square(z)
        }
        
        // Try to find the direct path (first peak) using an adaptive threshold.
        // Something like this, or a CFAR detector, will perform better in multipath
        // than just taking the overall maximum.
        var remoteIdx: UInt = 0
        var zMax: Float32 = 1e-6
        if #available(iOS 13.0, *) {
            
            // Threshold and look-ahead window for finding the true peak
            let thresh = 15*vDSP.mean(z)
            let nWin = 50
            
            // Find first sample to cross the threshold
            var idx = -1
            for i in 0...z.count {
                if z[i] > thresh {
                    idx = i
                    break
                }
            }

            // If the threshold was crossed, declare detection
            if idx >= 0 {
                
                // Get samples around the peak
                var zWin = Array(z[idx...(idx+nWin)])
                
                // Get maximum two samples within the window
                var p1: Float32
                var pIdx1: UInt
                (pIdx1, p1) = vDSP.indexOfMaximum(zWin)
                zWin[Int(pIdx1)] = 0
                var p2: Float32
                var pIdx2: UInt
                (pIdx2, p2) = vDSP.indexOfMaximum(zWin)
                
                // Sort by time
                if pIdx2 < pIdx1 {
                    let tmpIdx = pIdx1
                    let tmpP = p1
                    pIdx1 = pIdx2
                    pIdx2 = tmpIdx
                    p1 = p2
                    p2 = tmpP
                }
                
                // If the two are separated by more than 15 samples (~0.3 ms, or 3 inches),
                // take the first peak. Otherwise, take the largest peak.
                if pIdx2 - pIdx1 > 15 {
                    remoteIdx = pIdx1
                    zMax = p1
                } else {
                    if p2 > p1 {
                        remoteIdx = pIdx2
                        zMax = p2
                    } else {
                        remoteIdx = pIdx1
                        zMax = p1
                    }
                }
                
                // Update maximum index to be relative to buffer start
                remoteIdx += UInt(idx)
            }
            
        }
        let tRemote = Double(zLags[Int(remoteIdx)])*(1.0/fs)*1e9
        
        // SNR for remote received (uses noise from beginning)
        ultrasonicData.remoteSNR = 10*log10(Double(zMax/noiseMean))
                
        // Compute timing measurement and mark as valid
        if !ultrasonicData.localTimeValid {
            ultrasonicData.localTime = (tRemote + t) - ultrasonicData.sendTime - tDelta
            ultrasonicData.localTimeValid = true
        }
    }
    
}
