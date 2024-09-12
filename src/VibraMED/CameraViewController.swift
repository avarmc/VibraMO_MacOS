/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's primary view controller that presents the camera interface.
*/

import UIKit
import AVFoundation



typealias ImageBufferHandler = ((_ imageBuffer: CVPixelBuffer, _ timestamp: CMTime, _ outputBuffer: CVPixelBuffer?) -> ())

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,  ItemSelectionViewControllerDelegate {
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private var selectedSemanticSegmentationMatteTypes = [AVSemanticSegmentationMatte.MatteType]()
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    

    public var httpHelper: HttpHelper!
    
    
    public var engine: VIEngineProcessor!
    private var spinner: UIActivityIndicatorView!
    
    private var inProgressLivePhotoCapturesCount = 0
    
    
  
    private let sampleBufferQueue = DispatchQueue.global(qos: .userInteractive)
    
    private var imageBufferHandler: ImageBufferHandler?
    private var videoConnection: AVCaptureConnection! = nil
    private var videoOutput: AVCaptureVideoDataOutput? = nil
    private var faceDetector:FaceDetector!
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private var  startTime:Int64?
    
    @IBOutlet weak var engineView: VIEngineView!
    @IBOutlet private weak var previewView: PreviewView!
    @IBOutlet private weak var cameraButton: UIButton!
    @IBOutlet weak var measureButton: UIButton!
    @IBOutlet weak var presetButton: UIButton!
    @IBOutlet weak var measureProgress: GradientCircularProgressBar!
    @IBOutlet weak var qualityProgress: GradientCircularProgressBar!
    @IBOutlet weak var qualityType: UILabel!
    @IBOutlet weak var dbgText: UILabel!
    
    
    public var videoDevicePosition : AVCaptureDevice.Position{
        return (videoDeviceInput?.device.position)!
    }
    var windowOrientation: UIInterfaceOrientation {
        return view.window?.windowScene?.interfaceOrientation ?? .unknown
    }

    // MARK: View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
               
        startTime = getCurrentMillis()
        
        // Disable the UI. Enable the UI later, if and only if the session starts running.
        cameraButton.isEnabled = false
        
        // Set up the video preview view.
        previewView.session = session
        engine = VIEngineProcessor(self)
        httpHelper = HttpHelper(self)
        measureProgress.color = UIColor(red: 3.0, green: 1.0, blue: 0.3, alpha: 1)
        qualityProgress.color = UIColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 1)
        

        
        /*
         Check the video authorization status. Video access is required and audio
         access is optional. If the user denies audio access, AVCam won't
         record audio during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
        DispatchQueue.main.async {
            self.spinner = UIActivityIndicatorView(style: .large)
            self.spinner.color = UIColor.yellow
            self.previewView.addSubview(self.spinner)
            
            self.presetImage()
            self.updateProgress()
          
            self.httpHelper.navigateStart()
        }
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTime = getCurrentMillis()
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session if setup succeeded.
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    override var shouldAutorotate: Bool {
        // Disable autorotation of the interface when recording is in progress.
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }
            
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
            changeCamera(false)
        }
    }
    

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
     }
     
     func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if(engine.jni.engineGetIt("VI_FACE_ENABLE") != 0) {
            if(self.faceDetector == nil) {
                self.faceDetector = FaceDetector(self)
            }
            self.faceDetector.captureFace(output, didOutput: sampleBuffer, from: connection)
        } else {
            self.faceDetector = nil
        }
        
        self.engine.addImage(output,didOutput:sampleBuffer,from:connection)
        
        if let imageBufferHandler = imageBufferHandler, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) , connection == self.videoConnection
         {
             let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
             imageBufferHandler(imageBuffer, timestamp, nil)
         }
        
        DispatchQueue.main.async {
            self.updateProgress()
        }
     }
    
    public func onFace(_ r:CGRect) {      
        let x = r.origin.x + r.size.width/2
        let y = r.origin.y + r.size.height/2
        
        self.engine.jni.engineSetFace(Int32(x), and_y: Int32(y), and_w: Int32(r.size.width), and_h: Int32(r.size.height))
    }

    
    
    private func AddOutput() {
       
 
        self.videoOutput = AVCaptureVideoDataOutput()
                
        self.videoOutput?.alwaysDiscardsLateVideoFrames = true
        self.videoOutput?.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)
        self.videoOutput?.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) :
                                                 NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)] as [String : Any]
        self.videoOutput?.alwaysDiscardsLateVideoFrames = true
        
        if self.session.canAddOutput(self.videoOutput! )
        {
            self.session.addOutput(self.videoOutput!)
        }
        self.videoConnection = self.videoOutput?.connection(with: .video)
        self.engine.jni.enginePutIt("VI_VAR_RESET", and_v: 1)
        
        DispatchQueue.main.async {
            self.updateProgress()
        }
     }
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    

    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        /*
         Do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         */
        session.sessionPreset = .vga640x480
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera, if available, otherwise default to a wide angle camera.
            let prevDevice = UserDefaults.standard.string(forKey: "camera" )
            
            if( prevDevice != nil ) {
                if prevDevice == "dual" , let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .front) {
                    defaultVideoDevice = dualCameraDevice
                } else if prevDevice == "back" ,let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    // If a rear dual camera is not available, default to the rear wide angle camera.
                    defaultVideoDevice = backCameraDevice
                } else if prevDevice == "front" ,let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    // If the rear wide angle camera isn't available, default to the front wide angle camera.
                    defaultVideoDevice = frontCameraDevice
                }

            }
            
            if( defaultVideoDevice == nil ) {
                if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .front) {
                    defaultVideoDevice = dualCameraDevice
                    UserDefaults.standard.set("dual", forKey: "camera")
                } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    // If a rear dual camera is not available, default to the rear wide angle camera.
                    defaultVideoDevice = frontCameraDevice
                    UserDefaults.standard.set("back", forKey: "camera")
                } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    // If the rear wide angle camera isn't available, default to the front wide angle camera.
                    defaultVideoDevice = backCameraDevice
                    UserDefaults.standard.set("front", forKey: "camera")
                }
                UserDefaults.standard.synchronize()
            }
            
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    /*
                     Dispatch video streaming to the main queue because AVCaptureVideoPreviewLayer is the backing layer for PreviewView.
                     You can manipulate UIView only on the main thread.
                     Note: As an exception to the above rule, it's not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                     
                     Use the window scene's orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if self.windowOrientation != .unknown {
                        if let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: self.windowOrientation) {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                    
                    
                }
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        

        AddOutput()
                
        session.commitConfiguration()
    }
    
    
    
  
    // MARK: Device Configuration

    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                               mediaType: .video, position: .unspecified)
    
    
    @IBAction func measure(_ sender: Any) {
        httpHelper.onMeasureStart()
    }
    
    private func presetImage() {
        let preset = self.engine.getPreset()
        DispatchQueue.main.async {
            switch preset {
            case 0:
                self.presetButton.setImage(#imageLiteral(resourceName: "VI"), for: [])
                break
            case 1:
                self.presetButton.setImage(#imageLiteral(resourceName: "AV"), for: [])
                break
            case 2:
                self.presetButton.setImage(#imageLiteral(resourceName: "AR"), for: [])
                break
            case 3:
                self.presetButton.setImage(#imageLiteral(resourceName: "LD"), for: [])
                break
            default:
                break
            }
        }
    }
    
    @IBAction func preset(_ sender: Any) {
         sessionQueue.async {
            self.engine.nextPreset()
            self.presetImage()
        }
    }

    @IBAction private func changeCamera(_ cameraButton: UIButton) {
        DispatchQueue.main.async {
            self.changeCamera(true)
        }
    }
    

    private func changeCamera(_ change: Bool) {
        cameraButton.isEnabled = false

        engine.jni.measureAbort()
        
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            var preferredPosition: AVCaptureDevice.Position = currentPosition
            var preferredDeviceType: AVCaptureDevice.DeviceType = currentVideoDevice.deviceType
            
            if(change) {
                switch currentPosition {
                    case .unspecified, .front:
                        preferredPosition = .back
                        preferredDeviceType = .builtInDualCamera
                        UserDefaults.standard.set("back", forKey: "camera")
                    case .back:
                        preferredPosition = .front
                        preferredDeviceType = .builtInTrueDepthCamera
                        UserDefaults.standard.set("front", forKey: "camera")
                    @unknown default:
                        print("Unknown capture position. Defaulting to back, dual-camera.")
                        preferredPosition = .back
                        preferredDeviceType = .builtInDualCamera
                        UserDefaults.standard.set("back", forKey: "camera")
                }
                UserDefaults.standard.synchronize()
            }
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    
                    // Remove the existing device input first, because AVCaptureSession doesn't support
                    // simultaneous use of the rear and front cameras.
                    self.session.removeInput(self.videoDeviceInput)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
                        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
                        
                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                    if let connection = self.videoOutput?.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    
                    self.AddOutput()
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.cameraButton.isEnabled = true
              }
        }
    }
    
    @IBAction private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
        
        self.engine.jni.enginePutIt("VI_VAR_RESET", and_v: 1)
    }
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    public func onCheckResult(_ str:String) {
        if( str == "measure start") {
            self.measureProgress.color = UIColor(red: 0.1, green: 1.0, blue: 1.0, alpha: 0.8)
            return
        }
        
        if( str == "measure started") {
            self.measureProgress.color = UIColor(red: 0.1, green: 1.0, blue: 0.1, alpha: 0.8)
            return
        }
        
        if( str == "measure stopped") {
            self.measureProgress.color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1)
            return
        }
    }
    
    private func updateProgress() {
        updateProgressMeasure()
        updateProgressQuality()
        updateDbg()
    }
  
    private func updateDbg() {
        let dt = getCurrentMillis() - self.startTime!
        
        if dt < 10000 {
            let fpsI = self.engine.jni.engineGetFt("VI_VAR_FPSIN")
            let fpsR = self.engine.jni.engineGetFt("VI_VAR_FPSOUTR")
            self.dbgText.isHidden = false
            self.dbgText.text = String(format: "fps=%.1f/%.1f", fpsI,fpsR)
        } else
        if !self.dbgText.isHidden {
            self.dbgText.isHidden = true
        }
    }
    
    private func updateProgressMeasure() {
        let mProgress = self.engine.jni.engineGetFt("VI_INFO_M_PROGRESS")
        
        if mProgress > 0 && mProgress < 1 && httpHelper.bStarted {
            self.measureProgress.isHidden = false
            self.measureProgress.progress = CGFloat(mProgress)
        } else {
            self.measureProgress.isHidden = true
        }
    
    }
    
    private func updateProgressQuality() {
        let bQT = self.engine.jni.engineGetIt("VI_INFO_CHQ_SET_ENABLE")
        let tQT = self.engine.jni.engineGetIt("VI_INFO_CHQ_TEST_TYPE")
        let vQT = self.engine.jni.engineGetFt("VI_INFO_CHQ_TEST_VALUE")
        
        if bQT == 0 || tQT == 0 {
            self.qualityProgress.isHidden = true
            self.qualityType.isHidden = true
        } else {
            self.qualityProgress.isHidden = false
            self.qualityType.isHidden = false
            self.qualityProgress.progress = CGFloat(vQT/100.0)
            if vQT > 80 {
                qualityProgress.color = UIColor(red: 0.1, green: 1.0, blue: 0.1, alpha: 0.8)
            } else
            if vQT > 50 {
                qualityProgress.color = UIColor(red: 1.0, green: 1.0, blue: 0.1, alpha: 0.8)
            } else {
                qualityProgress.color = UIColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 0.8)
            }
            self.qualityType.text = String(format: "%d", tQT)
        }
    }
    
    // MARK: ItemSelectionViewControllerDelegate
    
    let semanticSegmentationTypeItemSelectionIdentifier = "SemanticSegmentationTypes"
    
    private func presentItemSelectionViewController(_ itemSelectionViewController: ItemSelectionViewController) {
        let navigationController = UINavigationController(rootViewController: itemSelectionViewController)
        navigationController.navigationBar.barTintColor = .black
        navigationController.navigationBar.tintColor = view.tintColor
        present(navigationController, animated: true, completion: nil)
    }
    
    func itemSelectionViewController(_ itemSelectionViewController: ItemSelectionViewController,
                                     didFinishSelectingItems selectedItems: [AVSemanticSegmentationMatte.MatteType]) {
        let identifier = itemSelectionViewController.identifier
        
        if identifier == semanticSegmentationTypeItemSelectionIdentifier {
            sessionQueue.async {
                self.selectedSemanticSegmentationMatteTypes = selectedItems
            }
        }
    }
    
     
  
   
 
    
    

    
    // MARK: KVO and Notifications
    
    private var keyValueObservations = [NSKeyValueObservation]()
    /// - Tag: ObserveInterruption
    private func addObservers() {
        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }

            DispatchQueue.main.async {
                // Only enable the ability to change camera if the device has more than one camera.
                self.cameraButton.isEnabled = isSessionRunning && self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
            }
        }
        keyValueObservations.append(keyValueObservation)
        
        let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /// - Tag: HandleRuntimeError
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                }
            }
        } else {
            
        }
    }
    
    /// - Tag: HandleSystemPressure
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        /*
         The frame rates used here are only for demonstration purposes.
         Your frame rate throttling may be different depending on your app's camera configuration.
         */
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
                do {
                    try self.videoDeviceInput.device.lockForConfiguration()
                    print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                    self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                    self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                    self.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    print("Could not lock device for configuration: \(error)")
                }
            
        } else if pressureLevel == .shutdown {
            print("Session stopped running due to shutdown system pressure level.")
        }
    }
    
    /// - Tag: HandleInterruption
    @objc
    func sessionWasInterrupted(notification: NSNotification) {
        /*
         In some scenarios you want to enable the user to resume the session.
         For example, if music playback is initiated from Control Center while
         using AVCam, then the user can let AVCam resume
         the session running, which will stop music playback. Note that stopping
         music playback in Control Center will not automatically resume the session.
         Also note that it's not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
          //  var showResumeButton = false
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
            //    showResumeButton = true
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Fade-in a label to inform the user that the camera is unavailable.
            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped running due to shutdown system pressure level.")
            }
            
        }
    }
    
    @objc
    func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
      

        
    }
    
    
    func getCurrentMillis()->Int64{
        return  Int64(NSDate().timeIntervalSince1970 * 1000)
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
    
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}

extension AVCaptureDevice.DiscoverySession {
    var uniqueDevicePositionsCount: Int {
        
        var uniqueDevicePositions = [AVCaptureDevice.Position]()
        
        for device in devices where !uniqueDevicePositions.contains(device.position) {
            uniqueDevicePositions.append(device.position)
        }
        
        return uniqueDevicePositions.count
    }
}


