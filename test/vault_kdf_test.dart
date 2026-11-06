import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/vault_crypto.dart';

void main() {
  test(
      'desktop derivation retains PBKDF2 compatibility without multi-second wait',
      () async {
    final salt = Uint8List.fromList(List.generate(32, (i) => i));
    final vectors = [
      (
        "synthetic-benchmark-password",
        '79ec2562c605a5150014e2b201bbf45f2fcb71078ee3021b6d168f8b02a8dedf'
      ),
      (
        "锁🔐ora\u0000密码",
        'bf431e135af3135797077a58999ae47267ef0cd509975dc008246771fd4da825'
      ),
      (
        "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        'a298fb22346f6e86ffff986b1eb2bf3363dd1bff2790cbf39f7dc598f43e9cd8'
      ),
    ];
    for (final (password, expected) in vectors) {
      final timer = Stopwatch()..start();
      final key = await VaultCrypto.derive(password, salt);
      expect(
          key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), expected);
      if (Platform.isMacOS || Platform.isWindows) {
        expect(timer.elapsedMilliseconds, lessThan(1000));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
