
@objc(ApperyioML) class ApperyioML : CDVPlugin {
    
    //MARK: - UI
    var previewView: PreviewView!
    var overlayView: OverlayView!
    private var pathType: PathType = .none
    private var setPathId: String?
 
    // MARK: Instance Variables
    // Holds the results at any time
    private var resultCallbackId: String?
    private var result: Result?
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000
    
    // MARK: Controllers that manage functionality
    private var cameraFeedManager: CameraFeedManager?
    private var modelDataHandler: ModelDataHandler?
    
    @objc(setPath:)
    func setPath(command: CDVInvokedUrlCommand) {
        self.setPathId = command.callbackId
        let args = command.arguments[0] as! Dictionary<String, String>
        self.pathType = PathType.init(rawValue: args["type"] ?? PathType.none.rawValue) ?? .none
        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: UIDocumentPickerMode.open)
        picker.delegate = self
        let vc = self.webView.parentViewController
        vc?.present(picker, animated: true)
        
    }
    
    /// Set TFLite model with camera view frame, and labels .txt
    @objc(setModelWithCamera:)
    func setModelWithCamera(command: CDVInvokedUrlCommand) {
        
        let args = command.arguments[0] as! Dictionary<String, Any>
        
        guard let params = InputWithCameraView(from: args) else {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: Settings.errorFindParams)
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            return
        }
        setup(params: params, id: command.callbackId)
    }
    
    private func setup(params: InputWithCameraView, id: String) {
        
        let webViewFrame = self.webView.frame
        var cameraFrame: CGRect!
        
        //  when set height ignoring bottom margin
        if let height = params.margins.height {
            cameraFrame = CGRect(x: params.margins.left, y: params.margins.top, width: Int(webViewFrame.size.width) - params.margins.left - params.margins.right, height: height)
        } else {
            cameraFrame = CGRect(x: params.margins.left, y: params.margins.top, width: Int(webViewFrame.size.width) - params.margins.left - params.margins.right, height: Int(webViewFrame.size.height) - params.margins.top - params.margins.bottom)
        }
        
        previewView = PreviewView(frame: cameraFrame)
        self.webView.addSubview(previewView)
        cameraFeedManager = CameraFeedManager(previewView: previewView)
        modelDataHandler = ModelDataHandler(modelPath: params.modelPath, fileInfoPath: params.labelsPath)
        overlayView = OverlayView(frame: cameraFrame)
        overlayView.backgroundColor = .clear
        previewView.addSubview(overlayView)
        cameraFeedManager!.delegate = self
        overlayView.clearsContextBeforeDrawing = true
        cameraFeedManager!.checkCameraConfigurationAndStartSession()
        self.resultCallbackId = id
    }

}

// MARK: TensorFlow
extension ApperyioML {
    
    @objc private func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
      // Run the live camera pixelBuffer through tensorFlow to get the result
      let currentTimeMs = Date().timeIntervalSince1970 * 1000
        guard  (currentTimeMs - previousInferenceTimeMs) >= Settings.delayBetweenInferencesMs else {
        return
      }

      previousInferenceTimeMs = currentTimeMs
      result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)

      guard let displayResult = result else {
        return
      }

      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)

      DispatchQueue.main.async {

        // Display results by handing off to the InferenceViewController
//        self.inferenceViewController?.resolution = CGSize(width: width, height: height)

//        var inferenceTime: Double = 0
//        if let resultInferenceTime = self.result?.inferenceTime {
//          inferenceTime = resultInferenceTime
//        }
//        self.inferenceViewController?.inferenceTime = inferenceTime
//        self.inferenceViewController?.tableView.reloadData()
          
          if let id = self.resultCallbackId {
              let output = Output(result: displayResult)
              let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: output.result)
              pluginResult?.setKeepCallbackAs(true)
              self.commandDelegate!.send(pluginResult, callbackId: id)
          }

        // Draws the bounding boxes and displays class names and confidence scores.
          print(displayResult.inferences)
        self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
      }
    }
    
    /**
     This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
     */
    private func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {

      self.overlayView.objectOverlays = []
      self.overlayView.setNeedsDisplay()

      guard !inferences.isEmpty else {
        return
      }

      var objectOverlays: [ObjectOverlay] = []

      for inference in inferences {

        // Translates bounding box rect to current view.
        var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

        if convertedRect.origin.x < 0 {
            convertedRect.origin.x = Settings.edgeOffset
        }

        if convertedRect.origin.y < 0 {
            convertedRect.origin.y = Settings.edgeOffset
        }

        if convertedRect.maxY > self.overlayView.bounds.maxY {
            convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - Settings.edgeOffset
        }

        if convertedRect.maxX > self.overlayView.bounds.maxX {
            convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - Settings.edgeOffset
        }

        let confidenceValue = Int(inference.confidence * 100.0)
        let string = "\(inference.className)  (\(confidenceValue)%)"

          let size = string.size(usingFont: Settings.displayFont)

          let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: Settings.displayFont)

        objectOverlays.append(objectOverlay)
      }

      // Hands off drawing to the OverlayView
      self.draw(objectOverlays: objectOverlays)
    }
    
    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    private func draw(objectOverlays: [ObjectOverlay]) {
      self.overlayView.objectOverlays = objectOverlays
      self.overlayView.setNeedsDisplay()
    }
    
}

extension ApperyioML: CameraFeedManagerDelegate {
    func didOutput(pixelBuffer: CVPixelBuffer) {
        runModel(onPixelBuffer: pixelBuffer)
    }
    func presentCameraPermissionsDeniedAlert() {
        sendError(message: Settings.cameraPermissionsDenied)
    }
    
    func presentVideoConfigurationErrorAlert() {
        sendError(message: Settings.videoConfigurationError)
    }
    
    func sessionRunTimeErrorOccurred() {
        sendError(message: Settings.sessionRunTimeErrorOccurred)
    }
    
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        sendError(message: Settings.sessionWasInterrupted)
    }
    
    func sessionInterruptionEnded() {
        sendError(message: Settings.sessionWasInterrupted)
    }
    
    private func sendError(message: String) {
        guard let id = resultCallbackId else { return }
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message)
        self.commandDelegate!.send(pluginResult, callbackId: id)
    }
    
}

extension ApperyioML: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var filePath = urls[0].absoluteString
        filePath = filePath.replacingOccurrences(of: "file://", with: "")//making url to file path
        print(filePath)
        UserDefaults.standard.set(filePath, forKey: self.pathType.rawValue)
        if let id = setPathId {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: filePath)
            self.commandDelegate!.send(pluginResult, callbackId: id)
        }
    }
}
