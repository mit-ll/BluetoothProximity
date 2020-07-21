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
    static var recvRemoteTime: Double = 0
    
    static var localSNR: Double = 0
    static var remoteSNR: Double = 0
    
    static var localDoppler: Double = 0
    static var remoteDoppler: Double = 0
}

class UltrasonicViewController: UIViewController {
    
    // Objects
    var tx: audioTx!
    var rx: audioRx!
    var engine: AVAudioEngine!
    
    // Objects from the AppDelegate
    var advertiser: BluetoothAdvertiser!
    var scanner: BluetoothScanner!
    var logger: Logger!
    
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
        
        // Create logger just for ranging
        logger = Logger()
        logger.createNewLog()
                
        // Setup to play and record in measurement mode
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("Failed to initialize AVAudioSession")
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
        rangeFeetLabel.text = "?"
        rangeInchesLabel.text = "?"
        localStatusLabel.text = "?"
        remoteStatusLabel.text = "?"
        localSNRLabel.text = "?"
        remoteSNRLabel.text = "?"
        localDopplerLabel.text = "?"
        remoteDopplerLabel.text = "?"
        
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
    // Each time we change the range, the counter is reset
    var range: Int!
    @IBOutlet weak var rangeLabel: UILabel!
    @IBOutlet weak var rangeStepper: UIStepper!
    @IBAction func rangeStepperChanged(_ sender: Any) {
        range = Int(rangeStepper.value)
        rangeLabel.text = range.description
        count = 0
        countLabel.text = count.description
    }
    
    // Run/stop button
    // When pressed from the leader, we run for nRunsToDo iterations
    var isRunning: Bool!
    var nRuns = 0
    var nRunsToDo = 1
    @IBOutlet weak var runStopButton: UIButton!
    @IBAction func runStopButtonPressed(_ sender: Any) {
        if !isRunning {
            nRuns = 0
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
            
            // Increment run count, and start another run (from the leader) if necessary
            self.nRuns += 1
            if !self.isFollower && (self.nRuns < self.nRunsToDo) {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
                    self.startRun()
                })
            }
            
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
    @IBOutlet weak var rangeFeetLabel: UILabel!
    @IBOutlet weak var rangeInchesLabel: UILabel!
    @IBOutlet weak var localStatusLabel: UILabel!
    @IBOutlet weak var remoteStatusLabel: UILabel!
    @IBOutlet weak var localTimeLabel: UILabel!
    @IBOutlet weak var remoteTimeLabel: UILabel!
    @IBOutlet weak var localSNRLabel: UILabel!
    @IBOutlet weak var remoteSNRLabel: UILabel!
    @IBOutlet weak var localDopplerLabel: UILabel!
    @IBOutlet weak var remoteDopplerLabel: UILabel!
    func twoWayRanging() {
                
        // Status
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
        
        // Times
        localTimeLabel.text = String(format: "%.1f", ultrasonicData.localTime/1e6)
        remoteTimeLabel.text = String(format: "%.1f", ultrasonicData.remoteTime/1e6)
        
        // SNRs
        localSNRLabel.text = String(format: "%.1f", ultrasonicData.localSNR)
        remoteSNRLabel.text = String(format: "%.1f", ultrasonicData.remoteSNR)
        
        // Dopplers
        localDopplerLabel.text = String(format: "%.1f", ultrasonicData.localDoppler)
        remoteDopplerLabel.text = String(format: "%.1f", ultrasonicData.remoteDoppler)
        
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
        
        // Log results
        let s = rangeLabel.text! + ",\(rangeFeetFrac),\(ultrasonicData.localTime),\(ultrasonicData.remoteTime),\(ultrasonicData.localSNR),\(ultrasonicData.remoteSNR),\(ultrasonicData.localDoppler),\(ultrasonicData.remoteDoppler)"
        logger.write(s)
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
        
        // Sample rate (samples/second)
        let fs: Double = AVAudioSession.sharedInstance().sampleRate
        if fs != 48000.0 {
            #if DEBUG
            print("Sample rate is \(fs)")
            #endif
        }
        
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
        // - 80 dB stopband attenuation
        let b: [Float32] = [-5.42012579794411e-06, -7.42674991848332e-05, 5.70267540732345e-05, -3.35869216320658e-05, -1.95789702817389e-05, 8.16406765788247e-05, -0.000115889798425084, 9.12513302043912e-05, -4.64774450628839e-06, -0.000108967924586654, 0.000188734061543157, -0.000179496973882089, 6.70246683024011e-05, 0.000104735315690107, -0.000248985089148017, 0.000280045724070198, -0.000164038170078759, -5.39795547020290e-05, 0.000266037713044246, -0.000356425711960525, 0.000267252927704168, -3.60979840109196e-05, -0.000219296737841260, 0.000364236113622163, -0.000323315963793019, 0.000124306420216247, 0.000118401188664336, -0.000272698631960354, 0.000268212258544303, -0.000135977983858741, -1.83293392857223e-05, 9.10640531368080e-05, -5.56336032139448e-05, -1.80484205821890e-05, 1.84516928722382e-05, 0.000111983769480804, -0.000308988577822784, 0.000404934331007311, -0.000238159291637461, -0.000209406347888578, 0.000743405024950607, -0.00102620537856752, 0.000770546184146143, 4.62191331598786e-05, -0.00108909140908913, 0.00178522935690191, -0.00162690133700573, 0.000502481143441479, 0.00114834281952640, -0.00248633554140182, 0.00269469372621641, -0.00146174023819814, -0.000755801155101961, 0.00287889107374771, -0.00373365055189504, 0.00270221902894867, -0.000134404228717556, -0.00274413246734564, 0.00442661177945479, -0.00393108928706251, 0.00137822890332248, 0.00200304590814920, -0.00448349774842081, 0.00474891784647994, -0.00262429945336044, -0.000806777028424903, 0.00377308204937047, -0.00477148864492746, 0.00337455275418060, -0.000433049443941723, -0.00243852761117642, 0.00378899068753833, -0.00312428522332554, 0.00110576091716895, 0.000945667567102872, -0.00191158292067823, 0.00155109020380543, -0.000558219750578531, -2.60865716160186e-05, -0.000357672857746678, 0.00130438466778648, -0.00168505999348914, 0.000506939005533622, 0.00216904952105164, -0.00493403489766892, 0.00570164916138000, -0.00306015640756295, -0.00250445210450921, 0.00838968824223815, -0.0110281684049141, 0.00793980363551109, 0.000456129780398547, -0.0104622441378890, 0.0166600723814432, -0.0147939552322301, 0.00446722814111071, 0.00998303395557807, -0.0212220385937077, 0.0226273641289560, -0.0121024177247069, -0.00617130045931789, 0.0232839690560403, -0.0299525794245508, 0.0215486349060696, -0.00107496552111037, -0.0217449706636452, 0.0351097244558294, -0.0312875131598564, 0.0110431251605565, 0.0161761109946885, -0.0366787676557178, 0.0394945463538607, -0.0222837977236784, -0.00701396264269838, 0.0338699734057401, -0.0444679835956023, 0.0329004309199284, -0.00446600161122376, -0.0267760739924483, 0.0450594142273405, -0.0409814085573146, 0.0164038329616231, 0.0164038329616231, -0.0409814085573146, 0.0450594142273405, -0.0267760739924483, -0.00446600161122376, 0.0329004309199284, -0.0444679835956023, 0.0338699734057401, -0.00701396264269838, -0.0222837977236784, 0.0394945463538607, -0.0366787676557178, 0.0161761109946885, 0.0110431251605565, -0.0312875131598564, 0.0351097244558294, -0.0217449706636452, -0.00107496552111037, 0.0215486349060696, -0.0299525794245508, 0.0232839690560403, -0.00617130045931789, -0.0121024177247069, 0.0226273641289560, -0.0212220385937077, 0.00998303395557807, 0.00446722814111071, -0.0147939552322301, 0.0166600723814432, -0.0104622441378890, 0.000456129780398547, 0.00793980363551109, -0.0110281684049141, 0.00838968824223815, -0.00250445210450921, -0.00306015640756295, 0.00570164916138000, -0.00493403489766892, 0.00216904952105164, 0.000506939005533622, -0.00168505999348914, 0.00130438466778648, -0.000357672857746678, -2.60865716160186e-05, -0.000558219750578531, 0.00155109020380543, -0.00191158292067823, 0.000945667567102872, 0.00110576091716895, -0.00312428522332554, 0.00378899068753833, -0.00243852761117642, -0.000433049443941723, 0.00337455275418060, -0.00477148864492746, 0.00377308204937047, -0.000806777028424903, -0.00262429945336044, 0.00474891784647994, -0.00448349774842081, 0.00200304590814920, 0.00137822890332248, -0.00393108928706251, 0.00442661177945479, -0.00274413246734564, -0.000134404228717556, 0.00270221902894867, -0.00373365055189504, 0.00287889107374771, -0.000755801155101961, -0.00146174023819814, 0.00269469372621641, -0.00248633554140182, 0.00114834281952640, 0.000502481143441479, -0.00162690133700573, 0.00178522935690191, -0.00108909140908913, 4.62191331598786e-05, 0.000770546184146143, -0.00102620537856752, 0.000743405024950607, -0.000209406347888578, -0.000238159291637461, 0.000404934331007311, -0.000308988577822784, 0.000111983769480804, 1.84516928722382e-05, -1.80484205821890e-05, -5.56336032139448e-05, 9.10640531368080e-05, -1.83293392857223e-05, -0.000135977983858741, 0.000268212258544303, -0.000272698631960354, 0.000118401188664336, 0.000124306420216247, -0.000323315963793019, 0.000364236113622163, -0.000219296737841260, -3.60979840109196e-05, 0.000267252927704168, -0.000356425711960525, 0.000266037713044246, -5.39795547020290e-05, -0.000164038170078759, 0.000280045724070198, -0.000248985089148017, 0.000104735315690107, 6.70246683024011e-05, -0.000179496973882089, 0.000188734061543157, -0.000108967924586654, -4.64774450628839e-06, 9.12513302043912e-05, -0.000115889798425084, 8.16406765788247e-05, -1.95789702817389e-05, -3.35869216320658e-05, 5.70267540732345e-05, -7.42674991848332e-05, -5.42012579794411e-06]
        
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
        fs = AVAudioSession.sharedInstance().sampleRate
        if fs != 48000.0 {
            #if DEBUG
            print("Sample rate is \(fs!)")
            #endif
        }
                
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
        ultrasonicData.localSNR = 10*log10(Double(yMax/noiseMean))
        
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
