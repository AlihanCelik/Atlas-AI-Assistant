import Cocoa
import FlutterMacOS
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Flutter MethodChannel kur
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.atlas.atlasApp/permissions",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "requestMicrophone":
        self?.requestMicrophone(result: result)
      case "checkMicrophone":
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        result(self?.statusToString(status))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func requestMicrophone(result: @escaping FlutterResult) {
    let current = AVCaptureDevice.authorizationStatus(for: .audio)
    print("[Atlas] Mikrofon mevcut durum: \(statusToString(current))")

    switch current {
    case .authorized:
      result("authorized")
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async {
          print("[Atlas] Mikrofon izni sonucu: \(granted)")
          result(granted ? "authorized" : "denied")
        }
      }
    case .denied:
      result("denied")
    case .restricted:
      result("restricted")
    @unknown default:
      result("unknown")
    }
  }

  private func statusToString(_ status: AVAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .restricted: return "restricted"
    @unknown default: return "unknown"
    }
  }
}
