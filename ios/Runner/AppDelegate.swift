import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let iCloudContainerIdentifier = "iCloud.com.hafdev.jadwly"
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
      case "latestBackup":
        result(strongSelf.latestICloudBackup())
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

  private func latestICloudBackup() -> [String: String]? {
    guard let directory = iCloudBackupsDirectory(create: false) else {
      return nil
    }

    var isDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return nil
    }

    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [
          .contentModificationDateKey,
          .isRegularFileKey,
          .ubiquitousItemDownloadingStatusKey,
          .ubiquitousItemIsDownloadingKey,
        ],
        options: [.skipsHiddenFiles]
      )
    else {
      return nil
    }

    let candidates = files.compactMap { fileURL -> (url: URL, date: Date, contents: String)? in
      guard fileURL.pathExtension.lowercased() == "json" else {
        return nil
      }
      guard
        let resourceValues = try? fileURL.resourceValues(
          forKeys: [.contentModificationDateKey, .isRegularFileKey]
        ),
        resourceValues.isRegularFile == true
      else {
        return nil
      }

      guard let contents = textContentsDownloadingIfNeeded(of: fileURL) else {
        return nil
      }

      let modifiedAt = resourceValues.contentModificationDate ?? Date.distantPast
      let backupDate = createdAtDate(forBackupContents: contents) ?? modifiedAt
      return (fileURL, backupDate, contents)
    }

    guard
      let latest = candidates.max(by: { $0.date < $1.date })
    else {
      return nil
    }

    return [
      "fileName": latest.url.lastPathComponent,
      "contents": latest.contents,
    ]
  }

  private func textContents(of fileURL: URL) -> String? {
    var contents: String?
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      readingItemAt: fileURL,
      options: [],
      error: &coordinationError
    ) { coordinatedURL in
      contents = try? String(contentsOf: coordinatedURL, encoding: .utf8)
    }
    return contents
  }

  private func textContentsDownloadingIfNeeded(of fileURL: URL) -> String? {
    if let contents = textContents(of: fileURL) {
      return contents
    }

    guard needsUbiquitousDownload(fileURL) else {
      return nil
    }

    try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)

    for _ in 0..<8 {
      Thread.sleep(forTimeInterval: 0.25)
      if let contents = textContents(of: fileURL) {
        return contents
      }
      if !needsUbiquitousDownload(fileURL) {
        return nil
      }
    }

    return nil
  }

  private func needsUbiquitousDownload(_ fileURL: URL) -> Bool {
    guard
      let resourceValues = try? fileURL.resourceValues(
        forKeys: [
          .ubiquitousItemDownloadingStatusKey,
          .ubiquitousItemIsDownloadingKey,
        ]
      )
    else {
      return false
    }

    if resourceValues.ubiquitousItemIsDownloading == true {
      return true
    }

    if let status = resourceValues.ubiquitousItemDownloadingStatus {
      return status != URLUbiquitousItemDownloadingStatus.current
    }

    return false
  }

  private func createdAtDate(forBackupContents contents: String) -> Date? {
    guard
      let data = contents.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let createdAt = json["createdAt"] as? String
    else {
      return nil
    }
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: createdAt) {
      return date
    }
    return ISO8601DateFormatter().date(from: createdAt)
  }

  private func iCloudBackupsDirectory(create: Bool) -> URL? {
    guard
      let containerURL = FileManager.default.url(
        forUbiquityContainerIdentifier: iCloudContainerIdentifier
      )
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
