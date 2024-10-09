import AVFoundation
import Accelerate

public class AudioRecorder: NSObject, AVAudioRecorderDelegate{
    var audioRecorder: AVAudioRecorder?
    var path: String?
    var hasPermission: Bool = false
    var useLegacyNormalization: Bool = false
    var audioUrl: URL?
    var recordedDuration: CMTime = CMTime.zero
    var maxAmplitude: Float = 0.0
    var audioEngine: AVAudioEngine?


    public func startRecording(_ result: @escaping FlutterResult, _ path: String?, _ encoder: Int?, _ sampleRate: Int?, _ bitRate: Int?, _ fileNameFormat: String, _ useLegacy: Bool?) {
        useLegacyNormalization = useLegacy ?? false
        let settings = [
            AVFormatIDKey: getEncoder(encoder ?? 0),
            AVSampleRateKey: sampleRate ?? 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let settingsWithBitrate = [
            AVEncoderBitRateKey: bitRate,
            AVFormatIDKey: getEncoder(encoder ?? 0),
            AVSampleRateKey: sampleRate ?? 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
        if path == nil {
            let directory = NSTemporaryDirectory()
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = fileNameFormat
            let fileName = dateFormatter.string(from: date) + ".m4a"

            self.audioUrl = NSURL.fileURL(withPathComponents: [directory, fileName])
        } else {
            self.audioUrl = URL(fileURLWithPath: path!)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: options)
            try AVAudioSession.sharedInstance().setActive(true)

            if let audioUrl = self.audioUrl {
                audioRecorder = try AVAudioRecorder(url: audioUrl, settings: bitRate != nil ? settingsWithBitrate as [String : Any] : settings as [String : Any])
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = true
                audioRecorder?.record()
            } else {
                result(FlutterError(code: "audioWaveforms", message: "Failed to initialize file URL", details: nil))
                return
            }

            audioEngine = AVAudioEngine()
            let inputNode = audioEngine?.inputNode
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            inputNode?.installTap(onBus: 0, bufferSize: 735, format: recordingFormat) { [weak self] (buffer, time) in
                guard let channelData = buffer.floatChannelData?[0] else { return }
                   // Debug: Print the first 10 samples of channelData
                   print(Array(UnsafeBufferPointer(start: channelData, count: 10)))
                   
                   // Alternative: Compute max amplitude manually
                   var maxVal: Float = 0.0
                   for i in 0..<buffer.frameLength {
                       let sample = channelData[Int(i)]
                       maxVal = max(maxVal, abs(sample))
                   }
                   
                   // Scale the amplitude to match Android's getMaxAmplitude() range (0 - 32767)
                   let scaledMaxAmplitude = maxVal * 32767.0
                   
                   // Update the maxAmplitude property
                   self?.maxAmplitude = scaledMaxAmplitude
                
//                        // Calculate the max amplitude
//                        var maxVal: Float = 0.0
//                        vDSP_maxv(channelData, 1, &maxVal, vDSP_Length(buffer.frameLength))
//
//                        // Scale the amplitude to match Android's getMaxAmplitude() range (0 - 32767)
//                        let scaledMaxAmplitude = maxVal * 32767.0
//
//                        // Update the maxAmplitude property
//                        self?.maxAmplitude = scaledMaxAmplitude
                    }
            audioEngine?.prepare()
            try audioEngine?.start()
            result(true)
        } catch {
            result(FlutterError(code: "audioWaveforms", message: "Failed to start recording", details: nil))
        }
    }
    
    public func stopRecording(_ result: @escaping FlutterResult) {
        // Stop AVAudioRecorder
        audioRecorder?.stop()
        audioRecorder = nil  // Release AVAudioRecorder

        // Stop AVAudioEngine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil  // Release AVAudioEngine

        // Your existing code for processing the recorded audio file
        if(audioUrl != nil) {
            let asset = AVURLAsset(url:  audioUrl!)
            if #available(iOS 15.0, *) {
                Task {
                    do {
                        recordedDuration = try await asset.load(.duration)
                        result([path,Int(recordedDuration.seconds * 1000).description])
                    } catch let err {
                        debugPrint(err.localizedDescription)
                        result([path,CMTime.zero.seconds.description])
                    }
                }
            } else {
                recordedDuration = asset.duration
                result([path,Int(recordedDuration.seconds * 1000).description])
            }
        } else {
            result([path,CMTime.zero.seconds.description])
        }
    }
        

    public func pauseRecording(_ result: @escaping FlutterResult) {
        // Pause AVAudioRecorder
        audioRecorder?.pause()

        // Pause AVAudioEngine (no built-in pause, so we stop it)
        audioEngine?.stop()
        
        result(false)
    }

    public func resumeRecording(_ result: @escaping FlutterResult) {
        // Resume AVAudioRecorder
        audioRecorder?.record()

        // Resume AVAudioEngine (restart it)
        do {
            try audioEngine?.start()
            result(true)
        } catch {
            result(FlutterError(code: "audioWaveforms", message: "Failed to resume recording", details: nil))
        }
    }
    
    // public func getDecibel(_ result: @escaping FlutterResult) {
    //     audioRecorder?.updateMeters()
    //     if(useLegacyNormalization){
    //         let amp = audioRecorder?.averagePower(forChannel: 0) ?? 0.0
    //         result(amp)
    //     } else {
    //         let amp = audioRecorder?.peakPower(forChannel: 0) ?? 0.0
    //         let linear = pow(10, amp / 20);
    //         result(linear)
    //     }
    // }

      public func getDecibel(_ result: @escaping FlutterResult) {
            if useLegacyNormalization {
                let db = 20 * log10(maxAmplitude)
                result(db)
            } else {
                result(maxAmplitude)
            }
            maxAmplitude = 0.0  // Reset maxAmplitude for the next call
        }

    
    public func checkHasPermission(_ result: @escaping FlutterResult){
        switch AVAudioSession.sharedInstance().recordPermission{
            
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    self.hasPermission = allowed
                }
            }
            break
        case .denied:
            hasPermission = false
            break
        case .granted:
            hasPermission = true
            break
        @unknown default:
            hasPermission = false
            break
        }
        result(hasPermission)
    }
    public func getEncoder(_ enCoder: Int) -> Int {
        switch(enCoder) {
        case Constants.kAudioFormatMPEG4AAC:
            return Int(kAudioFormatMPEG4AAC)
        case Constants.kAudioFormatMPEGLayer1:
            return Int(kAudioFormatMPEGLayer1)
        case Constants.kAudioFormatMPEGLayer2:
            return Int(kAudioFormatMPEGLayer2)
        case Constants.kAudioFormatMPEGLayer3:
            return Int(kAudioFormatMPEGLayer3)
        case Constants.kAudioFormatMPEG4AAC_ELD:
            return Int(kAudioFormatMPEG4AAC_ELD)
        case Constants.kAudioFormatMPEG4AAC_HE:
            return Int(kAudioFormatMPEG4AAC_HE)
        case Constants.kAudioFormatOpus:
            return Int(kAudioFormatOpus)
        case Constants.kAudioFormatAMR:
            return Int(kAudioFormatAMR)
        case Constants.kAudioFormatAMR_WB:
            return Int(kAudioFormatAMR_WB)
        case Constants.kAudioFormatLinearPCM:
            return Int(kAudioFormatLinearPCM)
        case Constants.kAudioFormatAppleLossless:
            return Int(kAudioFormatAppleLossless)
        case Constants.kAudioFormatMPEG4AAC_HE_V2:
            return Int(kAudioFormatMPEG4AAC_HE_V2)
        default:
            return Int(kAudioFormatMPEG4AAC)
        }
    }
}