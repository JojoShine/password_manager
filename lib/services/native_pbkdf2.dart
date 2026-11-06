import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CCDerive = Int32 Function(Uint32, Pointer<Uint8>, UintPtr,
    Pointer<Uint8>, UintPtr, Uint32, Uint32, Pointer<Uint8>, UintPtr);
typedef _Open = Int32 Function(
    Pointer<Pointer<Void>>, Pointer<Utf16>, Pointer<Utf16>, Uint32);
typedef _Close = Int32 Function(Pointer<Void>, Uint32);
typedef _BCryptDerive = Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32,
    Pointer<Uint8>, Uint32, Uint64, Pointer<Uint8>, Uint32, Uint32);

/// Called only inside the KDF worker isolate. Supported desktop failures
/// propagate; they must never silently weaken the KDF or change vault format.
Uint8List? deriveNativePbkdf2(
    Uint8List password, Uint8List salt, int iterations) {
  if (!Platform.isMacOS && !Platform.isWindows) return null;
  final input = calloc<Uint8>(password.isEmpty ? 1 : password.length);
  final saltBytes = calloc<Uint8>(salt.isEmpty ? 1 : salt.length);
  final output = calloc<Uint8>(32);
  try {
    input.asTypedList(password.length).setAll(0, password);
    saltBytes.asTypedList(salt.length).setAll(0, salt);
    int status;
    if (Platform.isMacOS) {
      final derive =
          DynamicLibrary.open('/usr/lib/system/libcommonCrypto.dylib')
              .lookupFunction<
                  _CCDerive,
                  int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int,
                      int, int, Pointer<Uint8>, int)>('CCKeyDerivationPBKDF');
      // kCCPBKDF2=2, kCCPRFHmacAlgSHA256=3 (CommonKeyDerivation.h).
      status = derive(2, input, password.length, saltBytes, salt.length, 3,
          iterations, output, 32);
    } else {
      final library = DynamicLibrary.open(
          '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\bcrypt.dll');
      final open = library.lookupFunction<
          _Open,
          int Function(Pointer<Pointer<Void>>, Pointer<Utf16>, Pointer<Utf16>,
              int)>('BCryptOpenAlgorithmProvider');
      final close =
          library.lookupFunction<_Close, int Function(Pointer<Void>, int)>(
              'BCryptCloseAlgorithmProvider');
      final derive = library.lookupFunction<
          _BCryptDerive,
          int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int,
              int, Pointer<Uint8>, int, int)>('BCryptDeriveKeyPBKDF2');
      final handle = calloc<Pointer<Void>>();
      final algorithm = 'SHA256'.toNativeUtf16(allocator: calloc);
      try {
        // BCRYPT_ALG_HANDLE_HMAC_FLAG=0x8; all reserved flags are zero.
        status = open(handle, algorithm, nullptr, 0x8);
        if (status != 0) {
          throw StateError('Native PBKDF2 initialization failed');
        }
        status = derive(handle.value, input, password.length, saltBytes,
            salt.length, iterations, output, 32, 0);
      } finally {
        if (handle.value != nullptr) close(handle.value, 0);
        calloc.free(algorithm);
        calloc.free(handle);
      }
    }
    if (status != 0) throw StateError('Native PBKDF2 derivation failed');
    return Uint8List.fromList(output.asTypedList(32));
  } finally {
    input.asTypedList(password.length).fillRange(0, password.length, 0);
    output.asTypedList(32).fillRange(0, 32, 0);
    calloc.free(input);
    calloc.free(saltBytes);
    calloc.free(output);
  }
}
