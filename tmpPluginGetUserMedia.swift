import Foundation
import AVFoundation
import WebRTC

class PluginGetUserMedia :  NSObject, AVCaptureFileOutputRecordingDelegate, AVAudioRecorderDelegate, AVCaptureVideoDataOutputSampleBufferDelegate   {
    var rtcPeerConnectionFactory: RTCPeerConnectionFactory
    
    var externalVideoBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    init(rtcPeerConnectionFactory: RTCPeerConnectionFactory) {
        NSLog("PluginGetUserMedia#init()")
        
        self.rtcPeerConnectionFactory = rtcPeerConnectionFactory
    }
    
    
    deinit {
        NSLog("PluginGetUserMedia#deinit()")
    }
    
    
    func call(
        _ constraints: NSDictionary,
        callback: (_ data: NSDictionary) -> Void,
        errback: (_ error: String) -> Void,
        eventListenerForNewStream: (_ pluginMediaStream: PluginMediaStream) -> Void
        ) {
        NSLog("PluginGetUserMedia#call()")
        
        let    audioRequested = constraints.object(forKey: "audio") as? Bool ?? false
        let    videoRequested = constraints.object(forKey: "video") as? Bool ?? false
        let    videoDeviceId = constraints.object(forKey: "videoDeviceId") as? String
        let    videoMinWidth = constraints.object(forKey: "videoMinWidth") as? Int ?? 0
        let    videoMaxWidth = constraints.object(forKey: "videoMaxWidth") as? Int ?? 0
        let    videoMinHeight = constraints.object(forKey: "videoMinHeight") as? Int ?? 0
        let    videoMaxHeight = constraints.object(forKey: "videoMaxHeight") as? Int ?? 0
        let    videoMinFrameRate = constraints.object(forKey: "videoMinFrameRate") as? Float ?? 0.0
        let    videoMaxFrameRate = constraints.object(forKey: "videoMaxFrameRate") as? Float ?? 0.0
        
        var rtcMediaStream: RTCMediaStream
        var pluginMediaStream: PluginMediaStream?
        var rtcAudioTrack: RTCAudioTrack?
        var rtcVideoTrack: RTCVideoTrack?
        var rtcVideoCapturer: RTCVideoCapturer?
        var rtcVideoSource: RTCAVFoundationVideoSource?
        var videoDevice: AVCaptureDevice?
        var mandatoryConstraints: [String: String] = [:]
        var constraints: RTCMediaConstraints
        
        
        
        if videoRequested == true {
            switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
            case AVAuthorizationStatus.notDetermined:
                NSLog("PluginGetUserMedia#call() | video authorization: not determined")
            case AVAuthorizationStatus.authorized:
                NSLog("PluginGetUserMedia#call() | video authorization: authorized")
            case AVAuthorizationStatus.denied:
                NSLog("PluginGetUserMedia#call() | video authorization: denied")
                errback("video denied")
                return
            case AVAuthorizationStatus.restricted:
                NSLog("PluginGetUserMedia#call() | video authorization: restricted")
                errback("video restricted")
                return
            }
        }
        
        if audioRequested == true {
            switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio) {
            case AVAuthorizationStatus.notDetermined:
                NSLog("PluginGetUserMedia#call() | audio authorization: not determined")
            case AVAuthorizationStatus.authorized:
                NSLog("PluginGetUserMedia#call() | audio authorization: authorized")
            case AVAuthorizationStatus.denied:
                NSLog("PluginGetUserMedia#call() | audio authorization: denied")
                errback("audio denied")
                return
            case AVAuthorizationStatus.restricted:
                NSLog("PluginGetUserMedia#call() | audio authorization: restricted")
                errback("audio restricted")
                return
            }
        }
        
        rtcMediaStream = self.rtcPeerConnectionFactory.mediaStream(withStreamId: UUID().uuidString)
        
        if videoRequested == true {
            // No specific video device requested.
            if videoDeviceId == nil {
                NSLog("PluginGetUserMedia#call() | video requested (device not specified)")
                
                for device: AVCaptureDevice in (AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! Array<AVCaptureDevice>) {
                    if device.position == AVCaptureDevicePosition.front {
                        videoDevice = device
                        break
                    }
                }
            }
                
                // Video device specified.
            else {
                NSLog("PluginGetUserMedia#call() | video requested (specified device id: '%@')", String(videoDeviceId!))
                
                for device: AVCaptureDevice in (AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! Array<AVCaptureDevice>) {
                    if device.uniqueID == videoDeviceId {
                        videoDevice = device
                        break
                    }
                }
            }
            
            if videoDevice == nil {
                NSLog("PluginGetUserMedia#call() | video requested but no suitable device found")
                
                errback("no suitable camera device found")
                return
            }
            
            NSLog("PluginGetUserMedia#call() | chosen video device: %@", String(describing: videoDevice!))
            
            rtcVideoCapturer = RTCVideoCapturer()
            // rtcVideoCapturer = RTCVideoCapturer(deviceName: videoDevice!.localizedName)
            
            if videoMinWidth > 0 {
                NSLog("PluginGetUserMedia#call() | adding media constraint [minWidth:%@]", String(videoMinWidth))
                // mandatoryConstraints.append(RTCPair(key: "minWidth", value: String(videoMinWidth)))
                mandatoryConstraints[kRTCMediaConstraintsMinWidth] = String(videoMinWidth)
            }
            if videoMaxWidth > 0 {
                NSLog("PluginGetUserMedia#call() | adding media constraint [maxWidth:%@]", String(videoMaxWidth))
                // mandatoryConstraints.append(RTCPair(key: "maxWidth", value: String(videoMaxWidth)))
                mandatoryConstraints[kRTCMediaConstraintsMaxWidth] = String(videoMaxWidth)
            }
            if videoMinHeight > 0 {
                NSLog("PluginGetUserMedia#call() | adding media constraint [minHeight:%@]", String(videoMinHeight))
                // mandatoryConstraints.append(RTCPair(key: "minHeight", value: String(videoMinHeight)))
                mandatoryConstraints[kRTCMediaConstraintsMinHeight] = String(videoMinHeight)
            }
            if videoMaxHeight > 0 {
                NSLog("PluginGetUserMedia#call() | adding media constraint [maxHeight:%@]", String(videoMaxHeight))
                // mandatoryConstraints.append(RTCPair(key: "maxHeight", value: String(videoMaxHeight)))
                mandatoryConstraints[kRTCMediaConstraintsMaxHeight] = String(videoMaxHeight)
            }
            if videoMinFrameRate > 0 {
                NSLog("PluginGetUserMedia#call() | adding media constraint [videoMinFrameRate:%@]", String(videoMinFrameRate))
                // mandatoryConstraints.append(RTCPair(key: "minFrameRate", value: String(videoMinFrameRate)))
                mandatoryConstraints[kRTCMediaConstraintsMinFrameRate] = String(videoMinFrameRate)
            }
            if videoMaxFrameRate > 0 {
                NSLog("PluginGetUserMedia#call() | adding media constraint [videoMaxFrameRate:%@]", String(videoMaxFrameRate))
                // mandatoryConstraints.append(RTCPair(key: "maxFrameRate", value: String(videoMaxFrameRate)))
                mandatoryConstraints[kRTCMediaConstraintsMaxFrameRate] = String(videoMaxFrameRate)
            }
            
            constraints = RTCMediaConstraints(
                mandatoryConstraints: mandatoryConstraints,
                optionalConstraints: [:]
            )
            
            rtcVideoSource = self.rtcPeerConnectionFactory.avFoundationVideoSource(with: constraints)
            if(videoDevice != nil) {
                if (videoDevice!.position == AVCaptureDevicePosition.back) {
                    rtcVideoSource?.useBackCamera = true
                } else {
                    rtcVideoSource?.useBackCamera = false
                }
                
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5000)) {
                    NSLog("HAHAHAHA");
                    
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .mixWithOthers)
                        try audioSession.setActive(true)
                        
                        let settings = [
                            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                            AVSampleRateKey: 44100,
                            AVNumberOfChannelsKey: 2,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                        ]
                        
                         let outputURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("audio.m4a")
                        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                        
                                            let fileManager: FileManager = FileManager.default
                                            if outputURL?.path != nil{
                                                if fileManager.fileExists(atPath: outputURL!.path) {
                                                    do{
                                                        try fileManager.removeItem(atPath: outputURL?.path as! String)
                                                    }
                                                    catch{
                                                        print(error)
                                                    }
                                                }
                                            }
                        
                        
                        
                        let audioRecorder = try AVAudioRecorder(url: outputURL!, settings: settings)
                            audioRecorder.delegate = self
                            audioRecorder.record()
                        
                        print(outputURL?.path);
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5000)) {
                            
                            do{
                                audioRecorder.stop()
                                NSLog("ENDED")
                                let bombSoundEffect = try AVAudioPlayer(contentsOf: outputURL!)
                                bombSoundEffect.prepareToPlay()
                                bombSoundEffect.volume = 1.0
                                bombSoundEffect.play()
                            } catch {
                                NSLog("ERROR");
                                 print(error)
                            }
                        }
                    } catch {
                        print("Setting category to AVAudioSessionCategoryPlayback failed.")
                    }
                
                    for output in (rtcVideoSource?.captureSession.outputs)! {
                        if let videoOutput = output as? AVCaptureVideoDataOutput {
                            NSLog("+++ FOUND A VIDEO OUTPUT: \(videoOutput) -> \(videoOutput.sampleBufferDelegate)")
                           
                            self.externalVideoBufferDelegate = videoOutput.sampleBufferDelegate
                            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
                        }
                    }
                   
//                    let outputURL = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("movie.mov")
//
//                    let movieOutput = AVCaptureMovieFileOutput();
//                    rtcVideoSource?.captureSession.addOutput(movieOutput);
//
//                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//                    let fileUrl = paths[0].appendingPathComponent("output.mov")
//
//                    let fileManager: FileManager = FileManager.default
//                    if outputURL?.path != nil{
//                        if fileManager.fileExists(atPath: outputURL!.path) {
//                            do{
//                                try fileManager.removeItem(atPath: outputURL?.path as! String)
//                            }
//                            catch{
//                                print(error)
//                            }
//                        }
//                    }
//                    movieOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
//
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5000)) {
//                        movieOutput.stopRecording()
//                        audioRecorder.stop()
                    }
                
                }
            
            }
            
            // If videoSource state is "ended" it means that constraints were not satisfied so
            // invoke the given errback.
            if (rtcVideoSource!.state == RTCSourceState.ended) {
                NSLog("PluginGetUserMedia() | rtcVideoSource.state is 'ended', constraints not satisfied")
                
                errback("constraints not satisfied")
                return
            }
            
            rtcVideoTrack = self.rtcPeerConnectionFactory.videoTrack(with: rtcVideoSource!, trackId: UUID().uuidString)
            rtcMediaStream.addVideoTrack(rtcVideoTrack!)
        }
        
        if audioRequested == true {
            NSLog("PluginGetUserMedia#call() | audio requested")
            rtcAudioTrack = self.rtcPeerConnectionFactory.audioTrack(withTrackId: UUID().uuidString)
            rtcMediaStream.addAudioTrack(rtcAudioTrack!)
        }
        
        pluginMediaStream = PluginMediaStream(rtcMediaStream: rtcMediaStream)
        pluginMediaStream!.run()
        
        // Let the plugin store it in its dictionary.
        eventListenerForNewStream(pluginMediaStream!)
        
        callback([
            "stream": pluginMediaStream!.getJSON()
            ])
    }
    
    func captureOutput(_ output: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        NSLog("CAPTURE");
        
        self.externalVideoBufferDelegate?.captureOutput!(output, didOutputSampleBuffer: sampleBuffer, from: connection)

    }
    
//    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
//
//        externalVideoBufferDelegate?.captureOutput!(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
//
//        dispatch_async(videoQueue) {
//            if self.assetWriterVideoInput.readyForMoreMediaData {
//                self.assetWriterVideoInput.appendSampleBuffer(sampleBuffer)
//            }
//        }
//    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
         NSLog("ERRROR finished");
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        NSLog("recording finished");
    }
    
    func capture(_ output: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        NSLog("didStartRecordingToOutputFileAt");
    }
    
    func capture(_ output: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        NSLog("didFinishRecordingToOutputFileAt");
        NSLog("@", outputFileURL.path);
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
    
    }
    
    
}


