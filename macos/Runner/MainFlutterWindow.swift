import Cocoa
import FlutterMacOS
import Sparkle

class MainFlutterWindow: NSWindow {
  private var updaterBridge: LockoraUpdater?
  private var migrationChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    RegisterGeneratedPlugins(registry: flutterViewController)
    let messenger = flutterViewController.engine.binaryMessenger
    updaterBridge = LockoraUpdater(messenger: messenger)
    migrationChannel = FlutterMethodChannel(name: "me.tbtparent.lockora/migration", binaryMessenger: messenger)
    migrationChannel?.setMethodCallHandler { call, result in
      guard call.method == "migrate" else { result(FlutterMethodNotImplemented); return }
      do {
        try LockoraPreferencesMigration.migrate()
        result(true)
      } catch {
        result(FlutterError(code: "migration_failed", message: error.localizedDescription, details: nil))
      }
    }
    super.awakeFromNib()
  }
}

// Runs before any Flutter preferences instance is created. Keep the old domain intact.
enum LockoraPreferencesMigration {
  static func migrate(defaults: UserDefaults = .standard,
                      target: String = "me.tbtparent.lockora",
                      legacy: String = "com.jojo.passwordmanager",
                      home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
    func applicationValues(_ values: [String: Any]) -> [String: Any] {
      values.filter { $0.key.hasPrefix("flutter.") }
    }
    func validate(_ values: [String: Any]) throws {
      func invalid() -> NSError {
        NSError(domain: "LockoraMigration", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "已有应用设置损坏，请恢复设置后重试。"])
      }
      guard let raw = values["flutter.app_settings"] else { return }
      guard let json = raw as? String, let data = json.data(using: .utf8),
            let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw invalid() }
      func validDate(_ value: Any?) -> Bool {
        guard let text = value as? String, !text.isEmpty else { return false }
        let formatter = ISO8601DateFormatter()
        let normalized = text.range(of: "[Zz]|[+-][0-9]{2}:[0-9]{2}$", options: .regularExpression) == nil ? text + "Z" : text
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: normalized) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: normalized) != nil
      }
      guard validDate(settings["created_at"]), validDate(settings["updated_at"]) else { throw invalid() }
      for key in ["master_password_hash", "app_version"] {
        if let value = settings[key], !(value is NSNull), !(value is String) { throw invalid() }
      }
      if let value = settings["last_unlock_time"], !(value is NSNull), !validDate(value) { throw invalid() }
      for key in ["auto_lock_timeout_minutes", "is_first_launch", "biometric_enabled"] {
        if let value = settings[key] {
          guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                number.doubleValue.rounded() == number.doubleValue else { throw invalid() }
        }
      }
    }
    func readDomain(_ name: String) throws -> [String: Any] {
      let file = home.appendingPathComponent("Library/Preferences/\(name).plist")
      // CFPreferences can hide corrupt on-disk input as an empty domain.
      if FileManager.default.fileExists(atPath: file.path) {
        let data = try Data(contentsOf: file)
        guard (try PropertyListSerialization.propertyList(from: data, format: nil)) is [String: Any] else {
          throw NSError(domain: "LockoraMigration", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "应用偏好文件损坏，请恢复后重试。"])
        }
      }
      return defaults.persistentDomain(forName: name) ?? [:]
    }
    let current = try readDomain(target)
    let currentApp = applicationValues(current)
    if !currentApp.isEmpty { try validate(currentApp); return }
    var old = applicationValues(try readDomain(legacy))
    if old.isEmpty {
      // Earlier sandboxed releases have a separate preferences container.
      let file = home.appendingPathComponent(
        "Library/Containers/\(legacy)/Data/Library/Preferences/\(legacy).plist")
      if FileManager.default.fileExists(atPath: file.path) {
        let data = try Data(contentsOf: file)
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
          throw NSError(domain: "LockoraMigration", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "无法读取旧版应用设置。"])
        }
        old = applicationValues(values)
      }
    }
    guard !old.isEmpty else { return }
    try validate(old)
    var merged = current
    old.forEach { merged[$0.key] = $0.value }
    defaults.setPersistentDomain(merged, forName: target)
    guard defaults.synchronize(),
          let saved = defaults.persistentDomain(forName: target),
          NSDictionary(dictionary: applicationValues(saved)).isEqual(to: old) else {
      // Restore the pre-migration domain so a retry cannot mistake a partial copy for success.
      defaults.setPersistentDomain(current, forName: target)
      defaults.synchronize()
      throw NSError(domain: "LockoraMigration", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "保存迁移设置失败，请重试。"])
    }
  }
}

// Availability controls starting a request. A successful preparation reply is the
// authorization to quit; Dart deliberately marks availability false while preparing.
struct LockoraInstallationAuthorization {
  private(set) var activeRequest: UUID?
  mutating func begin(canInstall: Bool) -> UUID? {
    guard canInstall, activeRequest == nil else { return nil }
    let request = UUID()
    activeRequest = request
    return request
  }
  mutating func complete(request: UUID, prepared: Bool) -> Bool? {
    guard request == activeRequest else { return nil }
    activeRequest = nil
    return prepared
  }
}

final class LockoraUpdater: NSObject, SPUUpdaterDelegate {
  static weak var shared: LockoraUpdater?
  private var installationRequested = false
  private var installationPrepared = false
  private let channel: FlutterMethodChannel
  private var controller: SPUStandardUpdaterController?
  private var canInstall = false
  private var authorization = LockoraInstallationAuthorization()
  private var preparationCompletion: ((Bool) -> Void)?
  private var timedOutPreparation: UUID?
  private var preparationPending: Bool { authorization.activeRequest != nil }
  private var pendingInstall: (() -> Void)?
  private var feedURL: URL?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "me.tbtparent.lockora/updater", binaryMessenger: messenger)
    super.init()
    Self.shared = self
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }

  private func status(_ value: String, _ message: String? = nil) {
    var arguments: [String: Any] = ["status": value]
    if let message = message { arguments["message"] = message }
    channel.invokeMethod("updateStatus", arguments: arguments)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "configure":
      guard controller == nil else { result(true); return }
      guard let feed = args["feedURL"] as? String, let url = URL(string: feed),
            url.scheme == "https", url.host != nil,
            let key = args["publicKey"] as? String, Data(base64Encoded: key)?.count == 32,
            Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String == key else {
        status("unconfigured", "更新源或签名公钥尚未配置。")
        result(FlutterError(code: "unconfigured", message: "更新源或签名公钥尚未配置。", details: nil)); return
      }
      feedURL = url
      let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
      self.controller = controller
      controller.updater.automaticallyDownloadsUpdates = false
      controller.updater.automaticallyChecksForUpdates = args["automaticChecks"] as? Bool ?? true
      controller.updater.updateCheckInterval = 86400
      do { try controller.updater.start(); status("idle"); result(true) }
      catch { self.controller = nil; status("error", error.localizedDescription); result(FlutterError(code: "configure_failed", message: error.localizedDescription, details: nil)) }
    case "checkForUpdates":
      guard let updater = controller?.updater else { result(FlutterError(code: "unconfigured", message: "更新尚未配置。", details: nil)); return }
      let background = args["background"] as? Bool ?? false
      if !updater.sessionInProgress {
        if background {
          if updater.automaticallyChecksForUpdates && Date().timeIntervalSince(updater.lastUpdateCheckDate ?? .distantPast) >= 86400 {
            status("checking"); updater.checkForUpdatesInBackground()
          } else { status("idle") }
        } else { status("checking"); controller?.checkForUpdates(nil) }
      } else if !background { controller?.checkForUpdates(nil) }
      result(true)
    case "setAutomaticChecks":
      controller?.updater.automaticallyChecksForUpdates = args["enabled"] as? Bool ?? false
      result(true)
    case "setCanInstall":
      canInstall = args["allowed"] as? Bool ?? false
      if canInstall { prepareInstallationIfNeeded() }
      result(true)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func finishPreparation(_ request: UUID, prepared: Bool) {
    guard let allowed = authorization.complete(request: request, prepared: prepared && timedOutPreparation != request) else { return }
    timedOutPreparation = nil
    let completion = preparationCompletion
    preparationCompletion = nil
    completion?(allowed)
  }

  private func prepareInstallation(onTimeout: (() -> Void)? = nil, completion: @escaping (Bool) -> Void) {
    guard let request = authorization.begin(canInstall: canInstall) else { completion(false); return }
    preparationCompletion = completion
    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
      guard let self = self, self.authorization.activeRequest == request else { return }
      // Wait for Dart's eventual completion before publishing recovery status, so
      // server restart cannot race a still-running stopServer operation.
      self.timedOutPreparation = request
      onTimeout?()
    }
    channel.invokeMethod("prepareInstall", arguments: nil) { [weak self] reply in
      self?.finishPreparation(request, prepared: (reply as? Bool) == true)
    }
  }

  private func prepareInstallationIfNeeded() {
    guard pendingInstall != nil, canInstall, !preparationPending else { return }
    prepareInstallation { [weak self] allowed in
      guard let self = self else { return }
      guard allowed else {
        self.status("blocked", "请先完成正在进行的编辑或保存，再安装更新。")
        return
      }
      let install = self.pendingInstall
      self.pendingInstall = nil
      self.installationPrepared = true
      install?()
    }
  }

  func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
               untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
    installationRequested = true
    pendingInstall = installHandler
    status("installing")
    if !canInstall { status("blocked", "请先完成正在进行的编辑或保存，再安装更新。") }
    prepareInstallationIfNeeded()
    return true
  }
  func applicationShouldTerminate() -> NSApplication.TerminateReply? {
    guard installationRequested else { return nil }
    if installationPrepared { return .terminateNow }
    guard canInstall, !preparationPending else {
      status("blocked", "请先完成正在进行的编辑或保存，再安装更新。")
      return .terminateCancel
    }
    var terminationReplied = false
    let reply: (Bool) -> Void = { allowed in
      guard !terminationReplied else { return }
      terminationReplied = true
      NSApp.reply(toApplicationShouldTerminate: allowed)
    }
    prepareInstallation(onTimeout: { reply(false) }) { [weak self] allowed in
      self?.installationPrepared = allowed
      if !allowed { self?.status("blocked", "更新安装准备未完成，请重试。") }
      reply(allowed)
    }
    return .terminateLater
  }
  func feedURLString(for updater: SPUUpdater) -> String? { feedURL?.absoluteString }
  func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
    installationRequested = true
  }
  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { status("available") }
  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    let info = (error as NSError).userInfo
    let reason = (info[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue ?? 0
    if reason == Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue) ||
       reason == Int(SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue) {
      status("upToDate")
    } else { status("error", error.localizedDescription) }
  }
  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    pendingInstall = nil
    if let request = authorization.activeRequest {
      timedOutPreparation = request
      installationRequested = false
      installationPrepared = false
      return // Publish recovery only after Dart has actually finished preparing.
    }
    installationRequested = false
    installationPrepared = false
    let nativeError = error as NSError
    if nativeError.domain == SUSparkleErrorDomain && nativeError.code == SUError.noUpdateError.rawValue { return }
    if nativeError.domain == SUSparkleErrorDomain && nativeError.code == SUError.installationCanceledError.rawValue {
      status("idle"); return
    }
    status("error", error.localizedDescription)
  }
}
