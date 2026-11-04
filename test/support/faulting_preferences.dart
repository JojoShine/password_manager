import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
// The plugin's platform interface is used only to inject persistence faults.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class FaultingPreferences extends InMemorySharedPreferencesStore {
  bool failLegacyRemoval = false;
  Completer<void>? activationStarted;
  Completer<void>? continueActivation;

  FaultingPreferences(SharedPreferences prefs)
      : super.withData({
          for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!
        });

  void install() => SharedPreferencesStorePlatform.instance = this;

  @override
  Future<bool> remove(String key) async {
    if (failLegacyRemoval && key == 'flutter.saved_passwords') return false;
    return super.remove(key);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.desktop_password_data_directory' &&
        activationStarted != null) {
      activationStarted!.complete();
      await continueActivation!.future;
    }
    return super.setValue(valueType, key, value);
  }
}
