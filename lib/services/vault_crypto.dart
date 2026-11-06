import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'native_pbkdf2_stub.dart' if (dart.library.io) 'native_pbkdf2.dart';

/// Desktop vault format. Header fields are authenticated, never secret.
class VaultCrypto {
  static const iterations = 600000;
  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }

  static Future<Uint8List> derive(String password, Uint8List salt) =>
      compute(_derive, (password, salt));

  static Uint8List _derive((String, Uint8List) input) {
    final password = Uint8List.fromList(utf8.encode(input.$1));
    try {
      final native = deriveNativePbkdf2(password, input.$2, iterations);
      if (native != null) return native;
      final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(input.$2, iterations, 32));
      return kdf.process(password);
    } finally {
      password.fillRange(0, password.length, 0);
    }
  }

  static Map<String, dynamic> _header(Uint8List salt) => {
        'version': 2,
        'cipher': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      };

  static Uint8List salt(Map<String, dynamic> document) {
    if (document['version'] != 2 ||
        document['cipher'] != 'AES-256-GCM' ||
        document['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        document['iterations'] != iterations) {
      throw const FormatException('Unsupported vault format');
    }
    final salt = base64Decode(document['salt'] as String);
    if (salt.length != 32) throw const FormatException('Invalid vault salt');
    return salt;
  }

  static String encrypt(List<String> records, Uint8List key, Uint8List salt) {
    final nonce = randomBytes(12);
    final header = _header(salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          true,
          AEADParameters(KeyParameter(key), 128, nonce,
              Uint8List.fromList(utf8.encode(jsonEncode(header)))));
    final encrypted =
        cipher.process(Uint8List.fromList(utf8.encode(jsonEncode(records))));
    return jsonEncode({
      ...header,
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(encrypted)
    });
  }

  static List<String> decrypt(Map<String, dynamic> document, Uint8List key) {
    final vaultSalt = salt(document);
    final nonce = base64Decode(document['nonce'] as String);
    final ciphertext = base64Decode(document['ciphertext'] as String);
    if (nonce.length != 12 || ciphertext.length < 16) {
      throw const FormatException('Invalid vault payload');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false,
          AEADParameters(KeyParameter(key), 128, nonce,
              Uint8List.fromList(utf8.encode(jsonEncode(_header(vaultSalt))))));
    Uint8List plaintext;
    try {
      plaintext = cipher.process(ciphertext);
    } on InvalidCipherTextException {
      throw const VaultAuthenticationException();
    }
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! List || decoded.any((value) => value is! String)) {
      throw const FormatException('Invalid vault records');
    }
    final records = decoded.cast<String>();
    for (final record in records) {
      if (jsonDecode(record) is! Map<String, dynamic>) {
        throw const FormatException('Invalid vault record');
      }
    }
    return records;
  }
}

/// Wrong credentials and authenticated-payload tampering are indistinguishable.
/// Format, filesystem and migration failures must not consume password attempts.
class VaultAuthenticationException implements Exception {
  const VaultAuthenticationException();
  @override
  String toString() => 'Vault authentication failed';
}
