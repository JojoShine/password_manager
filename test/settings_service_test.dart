import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old default app title upgrades to the new neutral default', () async {
    SharedPreferences.setMockInitialValues({
      'app_title': '甜宝塔的密码管理工具',
    });

    await SettingsService.instance.init();

    final prefs = await SharedPreferences.getInstance();
    expect(SettingsService.instance.appTitle, '密码管理工具');
    expect(prefs.getString('app_title'), '密码管理工具');
  });

  test('a custom app title is preserved', () async {
    SharedPreferences.setMockInitialValues({
      'app_title': '我的本地密码库',
    });

    await SettingsService.instance.init();

    expect(SettingsService.instance.appTitle, '我的本地密码库');
  });
}
