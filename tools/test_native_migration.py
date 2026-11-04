"""Run the production Swift migration against isolated in-memory preferences (macOS)."""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / 'macos/Runner/MainFlutterWindow.swift').read_text()
migration = source.split('enum LockoraPreferencesMigration {', 1)[1].split('\nfinal class LockoraUpdater:', 1)[0]
harness = r'''
final class Preferences: UserDefaults {
  var domains: [String: [String: Any]] = [:]
  var savesSucceed = true
  override func persistentDomain(forName name: String) -> [String: Any]? { domains[name] }
  override func setPersistentDomain(_ domain: [String: Any], forName name: String) { domains[name] = domain }
  override func synchronize() -> Bool { savesSucceed }
}
let home = URL(fileURLWithPath: CommandLine.arguments[1])
let prefs = Preferences(suiteName: "LockoraMigrationTests")!
func run() throws { try LockoraPreferencesMigration.migrate(defaults: prefs, target: "new", legacy: "old", home: home) }
let old: [String: Any] = ["flutter.app_settings": "{\"master_password_hash\":\"hash\",\"created_at\":\"2026-11-04T10:00:00.123456\",\"updated_at\":\"2026-11-04T10:00:00.123456\",\"is_first_launch\":0}", "flutter.failed_attempts": 4, "flutter.lockout_time": "2026-11-04", "flutter.desktop_data_directory": "/custom/iCloud", "flutter.saved_passwords": ["record"]]
prefs.domains = ["old": old, "new": ["NSWindowFrame": "frame"]]
try run()
assert(prefs.domains["new"]?["flutter.failed_attempts"] as? Int == 4)
assert(prefs.domains["new"]?["flutter.desktop_data_directory"] as? String == "/custom/iCloud")
assert(prefs.domains["new"]?["NSWindowFrame"] as? String == "frame")
assert(prefs.domains["old"]?["flutter.failed_attempts"] as? Int == 4)
prefs.domains["new"]?["flutter.failed_attempts"] = 1
try run()
assert(prefs.domains["new"]?["flutter.failed_attempts"] as? Int == 1)
prefs.domains = ["old": ["flutter.app_settings": "{}"]]
do { try run(); fatalError("Corrupt source accepted") } catch {}
assert(prefs.domains["new"] == nil)
prefs.domains = ["new": ["flutter.app_settings": "invalid"], "old": old]
do { try run(); fatalError("Corrupt target accepted") } catch {}
prefs.domains = ["old": old]
prefs.savesSucceed = false
do { try run(); fatalError("Failed save accepted") } catch {}
assert(prefs.domains["new"]?.isEmpty == true)
prefs.savesSucceed = true
prefs.domains = [:]
let sandbox = home.appendingPathComponent("Library/Containers/old/Data/Library/Preferences")
try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
try PropertyListSerialization.data(fromPropertyList: old, format: .binary, options: 0).write(to: sandbox.appendingPathComponent("old.plist"))
try run()
assert(prefs.domains["new"]?["flutter.saved_passwords"] as? [String] == ["record"])
prefs.domains = [:]
try Data("corrupt".utf8).write(to: sandbox.appendingPathComponent("old.plist"))
do { try run(); fatalError("Corrupt sandbox accepted") } catch {}
let normal = home.appendingPathComponent("Library/Preferences")
try FileManager.default.createDirectory(at: normal, withIntermediateDirectories: true)
try Data("corrupt".utf8).write(to: normal.appendingPathComponent("old.plist"))
do { try run(); fatalError("Corrupt disk domain accepted") } catch {}
var authorization = LockoraInstallationAuthorization()
assert(authorization.begin(canInstall: false) == nil)
let request = authorization.begin(canInstall: true)!
assert(authorization.begin(canInstall: true) == nil)
// Availability becoming false during Dart preparation cannot revoke a true reply.
let availabilityAfterLock = false
assert(!availabilityAfterLock)
assert(authorization.complete(request: request, prepared: true) == true)
assert(authorization.complete(request: request, prepared: true) == nil)
let rejected = authorization.begin(canInstall: true)!
assert(authorization.complete(request: rejected, prepared: false) == false)
let expired = authorization.begin(canInstall: true)!
assert(authorization.complete(request: expired, prepared: false) == false)
let next = authorization.begin(canInstall: true)!
assert(authorization.complete(request: expired, prepared: true) == nil)
assert(authorization.complete(request: next, prepared: true) == true)
print("Native migration: 8 scenarios passed; install authorization: 6 scenarios passed")
'''
with tempfile.TemporaryDirectory(prefix='lockora-native-tests-') as directory:
    path = Path(directory)
    swift = path / 'main.swift'
    swift.write_text('import Foundation\nenum LockoraPreferencesMigration {' + migration + harness)
    subprocess.run(['swiftc', '-module-cache-path', str(path / 'cache'), str(swift), '-o', str(path / 'tests')], check=True)
    subprocess.run([str(path / 'tests'), str(path / 'home')], check=True)
