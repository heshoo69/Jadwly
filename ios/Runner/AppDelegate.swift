import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var iCloudBackupsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudBackups") {
      setupICloudBackupsChannel(binaryMessenger: registrar.messenger())
    }
  }

  private func setupICloudBackupsChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.hafdev.jadwly/icloud_backups",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let strongSelf = self else {
        result(false)
        return
      }

      switch call.method {
      case "isAvailable":
        result(strongSelf.iCloudBackupsDirectory(create: false) != nil)
      case "saveBackup":
        result(strongSelf.saveICloudBackup(arguments: call.arguments))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    iCloudBackupsChannel = channel
  }

  private func saveICloudBackup(arguments: Any?) -> Bool {
    guard
      let arguments = arguments as? [String: Any],
      let fileName = arguments["fileName"] as? String,
      let contents = arguments["contents"] as? String,
      let directory = iCloudBackupsDirectory(create: true)
    else {
      return false
    }

    let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
    do {
      try contents.write(to: fileURL, atomically: true, encoding: .utf8)
      return true
    } catch {
      return false
    }
  }

  private func iCloudBackupsDirectory(create: Bool) -> URL? {
    guard
      let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
    else {
      return nil
    }

    let directory = containerURL
      .appendingPathComponent("Documents", isDirectory: true)
      .appendingPathComponent("Jadwly", isDirectory: true)
      .appendingPathComponent("Backups", isDirectory: true)

    if create {
      do {
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
      } catch {
        return nil
      }
    }

    return directory
  }
}
