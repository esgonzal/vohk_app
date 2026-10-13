import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var incomingCallChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Twilio's PushKit token and Firebase's ordinary APNs token are separate.
    // Explicitly start ordinary remote-notification registration so Firebase
    // can map the APNs token to an FCM registration token on every launch.
    application.registerForRemoteNotifications()
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "cl.vohk.comunidades/incoming_call",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "consumePendingIncomingCall":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    incomingCallChannel = channel
  }
}
