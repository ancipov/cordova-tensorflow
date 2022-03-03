import UIKit

class Settings {
    static let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    static let edgeOffset: CGFloat = 2.0
    static let labelOffset: CGFloat = 10.0
    static let animationDuration = 0.5
    static let collapseTransitionThreshold: CGFloat = -30.0
    static let expandTransitionThreshold: CGFloat = 30.0
    static let delayBetweenInferencesMs: Double = 200
    
    //errors
    static let errorFindParams = "Failed to find \"modelPath\" or \"labelsPath\""
    static let cameraPermissionsDenied = "Camera permissions denied"
    static let videoConfigurationError = "Video configuration error"
    static let sessionRunTimeErrorOccurred = "Session run time error occurred"
    static let sessionWasInterrupted = "Session was interrupted"
    
}

struct InputWithCameraView: Codable {
    var modelPath: String?
    var labelsPath: String?
    let margins: Margins
}

struct Margins: Codable {
    var left: Int = 0
    var right: Int = 0
    var top: Int = 0
    var bottom: Int = 0
    let height: Int?
}

enum PathType: String {
    case modelPath = "modelPath"
    case labelsPath = "labelsPath"
    case none = "none"
}
