import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/local_password_store.dart';

void main() {
  late Directory directory;
  late LocalPasswordStore first;
  late LocalPasswordStore second;
  final original = [
    jsonEncode({'id': 1, 'password': 'original'})
  ];
  final remote = [
    jsonEncode({'id': 1, 'password': 'remote'})
  ];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pm_cloud_');
    first = LocalPasswordStore(directory: directory);
    second = LocalPasswordStore(directory: directory);
    await first.writePasswords(original);
    await second.readPasswords();
  });
  tearDown(() => directory.delete(recursive: true));

  test('stale writer cannot overwrite externally changed passwords', () async {
    await second.writePasswords(remote);
    await expectLater(
        first.writePasswords(original), throwsA(isA<PasswordStoreException>()));
    expect(await second.readPasswords(), remote);
  });

  test('explicit snapshot protects a UI after another consumer reloads',
      () async {
    await second.writePasswords(remote);
    await first.readPasswords();
    await expectLater(
        first.writePasswords(original, expectedPasswords: original),
        throwsA(isA<PasswordStoreException>()));
    expect(await first.readPasswords(), remote);
  });

  test('reloading externally changed data permits a subsequent edit', () async {
    await second.writePasswords(remote);
    expect(await first.readPasswords(), remote);
    await first.writePasswords(original);
    expect(await second.readPasswords(), original);
  });

  test('simultaneous local writes from one snapshot reject the stale edit',
      () async {
    final results = await Future.wait([
      first.writePasswords(remote).then((_) => true).catchError((_) => false),
      first.writePasswords(original).then((_) => true).catchError((_) => false),
    ]);
    expect(results, [true, false]);
    expect(await first.readPasswords(), remote);
  });
}
