import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var cardioRecorder: CardioRecorder?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    cardioRecorder = CardioRecorder()
    if let controller = window?.rootViewController as? FlutterViewController {
      CardioHostApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: cardioRecorder)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
