@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:password_manager/services/vault_crypto.dart';

void main() {
  late Directory directory;
  late LocalPasswordStore store;
  final records = [
    jsonEncode(
        {'id': 1, 'title': 'private-title', 'password': 'secret-password'})
  ];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vault_');
    store = LocalPasswordStore(directory: directory);
  });
  tearDown(() => directory.delete(recursive: true));
  test('desktop persistence requires an unlocked session', () async {
    await expectLater(
        store.writePasswords(records), throwsA(isA<PasswordStoreException>()));
    expect(await store.passwordFile.exists(), isFalse);
  });
  test('default disk document never contains plaintext records', () async {
    await store.unlock('test-master');
    await store.writePasswords(records);
    expect(await store.passwordFile.readAsString(),
        isNot(contains('secret-password')));
  });
  test('PBKDF2 output matches an independently computed SHA256 vector',
      () async {
    final key = await VaultCrypto.derive(
        'vector-password', Uint8List.fromList(List.generate(32, (i) => i)));
    expect(key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'cf0ab09069d88ac7c254b6e1ce0c6a97c4bafe179d0a25f0c90f8e06b0410372');
  });
  test('successful rotation encrypts main and backup with the new password',
      () async {
    await store.unlock('old');
    await store.writePasswords(records);
    final oldSalt =
        (jsonDecode(await store.passwordFile.readAsString()) as Map)['salt'];
    await store.changeMasterPassword('old', 'new');
    final main = jsonDecode(await store.passwordFile.readAsString())
        as Map<String, dynamic>;
    expect(main['salt'], isNot(oldSalt));
    final key = await VaultCrypto.derive('new', VaultCrypto.salt(main));
    for (final file in [store.passwordFile, store.backupFile]) {
      expect(
          VaultCrypto.decrypt(
              jsonDecode(await file.readAsString()) as Map<String, dynamic>,
              key),
          records);
    }
  });
  test('every active file is encrypted; each save uses a fresh nonce',
      () async {
    await store.unlock('master');
    await store.writePasswords(records);
    final first = jsonDecode(await store.passwordFile.readAsString()) as Map;
    await store.writePasswords(records);
    final second = jsonDecode(await store.passwordFile.readAsString()) as Map;
    expect(first['salt'], second['salt']);
    expect(first['nonce'], isNot(second['nonce']));
    for (final file in [store.passwordFile, store.backupFile]) {
      final bytes = await file.readAsString();
      expect(bytes, isNot(contains('secret-password')));
      expect(bytes, isNot(contains('private-title')));
    }
    expect(second['iterations'], 600000);
    expect(base64Decode(second['salt'] as String), hasLength(32));
    expect(base64Decode(second['nonce'] as String), hasLength(12));
  });
  test('wrong password and tampering do not recover over primary', () async {
    await store.unlock('master');
    await store.writePasswords(records);
    final raw = await store.passwordFile.readAsString();
    store.lock();
    await expectLater(
        store.unlock('wrong'), throwsA(isA<PasswordStoreException>()));
    expect(await store.passwordFile.readAsString(), raw);
    final document = jsonDecode(raw) as Map<String, dynamic>;
    final payload = base64Decode(document['ciphertext'] as String);
    payload[0] ^= 1;
    document['ciphertext'] = base64Encode(payload);
    final tampered = jsonEncode(document);
    await store.passwordFile.writeAsString(tampered);
    await expectLater(
        store.unlock('master'), throwsA(isA<PasswordStoreException>()));
    expect(await store.passwordFile.readAsString(), tampered);
    expect(store.isUnlocked, isFalse);
  });
  test('authenticated headers and strict KDF and nonce lengths reject tamper',
      () async {
    final key = VaultCrypto.randomBytes(32);
    final raw = VaultCrypto.encrypt(records, key, VaultCrypto.randomBytes(32));
    for (final field in [
      'salt',
      'nonce',
      'ciphertext',
      'iterations',
      'cipher',
      'version'
    ]) {
      final document = jsonDecode(raw) as Map<String, dynamic>;
      document[field] = switch (field) {
        'iterations' => 1,
        'version' => 3,
        'cipher' => 'AES-CBC',
        _ => base64Encode([1, 2, 3]),
      };
      expect(() => VaultCrypto.decrypt(document, key), throwsA(anything));
    }
    expect(VaultCrypto.decrypt(jsonDecode(raw) as Map<String, dynamic>, key),
        records);
  });
  test('legacy primary and backup migrate without plaintext residuals',
      () async {
    final legacy = jsonEncode(
        {'version': 1, 'passwords': records.map(jsonDecode).toList()});
    await directory.create(recursive: true);
    await store.passwordFile.writeAsString(legacy);
    await store.backupFile.writeAsString(legacy);
    await store.temporaryFile.writeAsString(legacy);
    await store.unlock('master');
    expect(await store.readPasswords(), records);
    for (final file in [store.passwordFile, store.backupFile]) {
      expect(await file.readAsString(), isNot(contains('secret-password')));
    }
    expect(await store.temporaryFile.exists(), isFalse);
  });
  test('missing primary never initializes empty over backup or temporary data',
      () async {
    await store.unlock('master');
    await store.passwordFile.delete();
    store.lock();
    await expectLater(
        store.unlock('master'), throwsA(isA<PasswordStoreException>()));
    expect(await store.passwordFile.exists(), isFalse);
    await store.backupFile.rename(store.temporaryFile.path);
    await expectLater(
        store.unlock('master'), throwsA(isA<PasswordStoreException>()));
    expect(await store.passwordFile.exists(), isFalse);
  });
  test(
      'fresh second device opens same vault and rejects stale same-content write',
      () async {
    await store.unlock('master');
    await store.writePasswords(records);
    final remote = LocalPasswordStore(directory: directory);
    await remote.unlock('master');
    expect(await remote.readPasswords(), records);
    await remote.writePasswords(records);
    await expectLater(
        store.writePasswords(records), throwsA(isA<PasswordStoreException>()));
    await store.readPasswords();
    await store.writePasswords(records);
  });
  test('remote password rotation cannot be overwritten by old-key session',
      () async {
    await store.unlock('master');
    await store.writePasswords(records);
    final remote = LocalPasswordStore(directory: directory);
    await remote.unlock('master');
    await remote.changeMasterPassword('master', 'new-master');
    final rotated = await store.passwordFile.readAsString();
    await expectLater(
        store.readPasswords(), throwsA(isA<PasswordStoreException>()));
    await expectLater(
        store.writePasswords(records), throwsA(isA<PasswordStoreException>()));
    expect(await store.passwordFile.readAsString(), rotated);
    store.lock();
    await expectLater(
        store.unlock('master'), throwsA(isA<PasswordStoreException>()));
    await store.unlock('new-master');
    expect(await store.readPasswords(), records);
  });
  test('lock invalidates a pending derivation', () async {
    final unlocking = store.unlock('master');
    store.lock();
    await expectLater(unlocking, throwsA(isA<PasswordStoreException>()));
    expect(store.isUnlocked, isFalse);
    expect(await store.passwordFile.exists(), isFalse);
  });
  for (final stage in ['temporary', 'backup', 'rename']) {
    test('rotation failure at $stage leaves old primary authoritative',
        () async {
      await store.unlock('old');
      await store.writePasswords(records);
      final original = await store.passwordFile.readAsString();
      final failing = _FailingStore(directory: directory, stage: stage);
      await failing.unlock('old');
      failing.fail = true;
      await expectLater(
          failing.changeMasterPassword('old', 'new'), throwsA(anything));
      expect(await store.passwordFile.readAsString(), original);
      expect(await store.readPasswords(), records);
      final fresh = LocalPasswordStore(directory: directory);
      await fresh.unlock('old');
      expect(await fresh.readPasswords(), records);
      if (await store.temporaryFile.exists()) {
        expect(await store.temporaryFile.readAsString(),
            isNot(contains('secret-password')));
      }
    });
  }
}

class _FailingStore extends LocalPasswordStore {
  final String stage;
  bool fail = false;
  _FailingStore({required super.directory, required this.stage});
  @override
  File get temporaryFile => _FailureFile(super.temporaryFile,
      () => fail && stage == 'temporary', () => fail && stage == 'rename');
  @override
  File get backupFile => _FailureFile(
      super.backupFile, () => fail && stage == 'backup', () => false);
}

class _FailureFile implements File {
  final File file;
  final bool Function() failWrite;
  final bool Function() failRename;
  _FailureFile(this.file, this.failWrite, this.failRename);
  @override
  String get path => file.path;
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      file.readAsString(encoding: encoding);
  @override
  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    if (failWrite()) throw const FileSystemException('injected write failure');
    return file.writeAsString(contents,
        mode: mode, encoding: encoding, flush: flush);
  }

  @override
  Future<File> rename(String newPath) {
    if (failRename())
      throw const FileSystemException('injected rename failure');
    return file.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
