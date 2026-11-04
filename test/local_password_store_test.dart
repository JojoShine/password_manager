import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/local_password_store.dart';

void main() {
  group('desktop password data paths', () {
    test('resolves macOS application support directory', () {
      expect(
        LocalPasswordStore.resolveDataDirectory(
          LocalPasswordPlatform.macOS,
          {'HOME': '/Users/tester'},
        ),
        '/Users/tester/Library/Application Support/PasswordManager',
      );
    });

    test('resolves Windows roaming app data directory', () {
      expect(
        LocalPasswordStore.resolveDataDirectory(
          LocalPasswordPlatform.windows,
          {'APPDATA': r'C:\Users\tester\AppData\Roaming'},
        ),
        r'C:\Users\tester\AppData\Roaming\PasswordManager',
      );
    });

    test('places a selected Windows location in a PasswordManager child folder',
        () {
      expect(
        LocalPasswordStore.resolveWindowsSelectedDataDirectory(
          r'D:\Portable Apps',
        ),
        r'D:\Portable Apps\PasswordManager',
      );
      expect(
        LocalPasswordStore.resolveWindowsSelectedDataDirectory(
          'D:\\Portable Apps\\',
        ),
        r'D:\Portable Apps\PasswordManager',
      );
    });

    test('resolves Linux XDG data directory with home fallback', () {
      expect(
        LocalPasswordStore.resolveDataDirectory(
          LocalPasswordPlatform.linux,
          {'XDG_DATA_HOME': '/data/tester', 'HOME': '/home/tester'},
        ),
        '/data/tester/PasswordManager',
      );
      expect(
        LocalPasswordStore.resolveDataDirectory(
          LocalPasswordPlatform.linux,
          {'HOME': '/home/tester'},
        ),
        '/home/tester/.local/share/PasswordManager',
      );
    });
  });

  group('desktop password files', () {
    late Directory tempDirectory;
    late LocalPasswordStore store;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('pm_store_test_');
      store = LocalPasswordStore(directory: tempDirectory);
      await store.unlock('test-master');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('writes a versioned JSON document and backup', () async {
      final passwords = [
        jsonEncode({'id': 1, 'title': 'Example', 'password': 'secret'}),
      ];

      await store.writePasswords(passwords);

      final document = jsonDecode(await store.passwordFile.readAsString())
          as Map<String, dynamic>;
      expect(document['version'], 2);
      expect(document['ciphertext'], isA<String>());
      expect(document.containsKey('passwords'), isFalse);
      expect(await store.backupFile.exists(), isTrue);
      expect(await store.readPasswords(), passwords);
    });

    test('does not overwrite corrupt primary from older backup', () async {
      await store.writePasswords([
        jsonEncode({'id': 1})
      ]);
      await store.passwordFile.writeAsString('{broken');
      await expectLater(
          store.readPasswords(), throwsA(isA<PasswordStoreException>()));
      expect(await store.passwordFile.readAsString(), '{broken');
    });

    test('throws when primary and backup are both corrupt', () async {
      await store.directory.create(recursive: true);
      await store.passwordFile.writeAsString('{broken');
      await store.backupFile.writeAsString('{also broken');

      expect(store.readPasswords, throwsA(isA<PasswordStoreException>()));
    });

    test('clear keeps an authenticated empty vault and directory', () async {
      await store.writePasswords([
        jsonEncode({'id': 1})
      ]);

      await store.clearPasswords();

      expect(await store.readPasswords(), isEmpty);
      expect(await store.backupFile.exists(), isTrue);
      expect(await store.directory.exists(), isTrue);
    });

    test('migration copies and verifies passwords without deleting the source',
        () async {
      final targetDirectory =
          await Directory.systemTemp.createTemp('pm_store_target_');
      addTearDown(() async {
        if (await targetDirectory.exists()) {
          await targetDirectory.delete(recursive: true);
        }
      });
      final passwords = [
        jsonEncode({'id': 1, 'title': 'Migrated', 'password': 'secret'}),
      ];
      await store.writePasswords(passwords);

      final target = LocalPasswordStore(directory: targetDirectory);
      await target.unlock('test-master', initialPasswords: passwords);
      await store.copyPasswordsTo(target);
      expect(await target.readPasswords(), passwords);
      expect(await store.readPasswords(), passwords);
    });

    test('migration refuses to overwrite different password data', () async {
      final targetDirectory =
          await Directory.systemTemp.createTemp('pm_store_target_');
      addTearDown(() async {
        if (await targetDirectory.exists()) {
          await targetDirectory.delete(recursive: true);
        }
      });
      await store.writePasswords([
        jsonEncode({'id': 1, 'title': 'Source'}),
      ]);
      final target = LocalPasswordStore(directory: targetDirectory);
      await target.unlock('test-master');
      await target.writePasswords([
        jsonEncode({'id': 2, 'title': 'Existing target'}),
      ]);

      expect(
        () => store.copyPasswordsTo(target),
        throwsA(isA<PasswordStoreException>()),
      );
      expect(
        await target.readPasswords(),
        [
          jsonEncode({'id': 2, 'title': 'Existing target'})
        ],
      );
    });
  });

  test('macOS legacy reader extracts known keys one at a time', () async {
    final calls = <List<String>>[];
    final reader = MacLegacyPreferencesReader(
      preferencesFile: File('/tmp/legacy.plist'),
      processRunner: (executable, arguments) async {
        calls.add(arguments);
        if (arguments[1] == r'flutter\.saved_passwords') {
          return ProcessResult(
            1,
            0,
            jsonEncode([
              jsonEncode({'id': 1, 'title': 'Legacy'}),
            ]),
            '',
          );
        }
        if (arguments[1] == r'flutter\.app_settings') {
          return ProcessResult(1, 0, jsonEncode('settings-json'), '');
        }
        return ProcessResult(1, 1, '', 'missing');
      },
    );

    final values = await reader.readSupportedPreferences();

    expect(values['saved_passwords'], hasLength(1));
    expect(values['app_settings'], 'settings-json');
    expect(calls, isNotEmpty);
    expect(
      calls.every((arguments) =>
          arguments.contains('-extract') && !arguments.contains('-convert')),
      isTrue,
    );
  });
}
