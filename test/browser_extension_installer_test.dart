import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/browser_extension_installer.dart';

void main() {
  test('prepares bundled extension files in a permanent versioned directory',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm_extension_');
    addTearDown(() => directory.delete(recursive: true));
    final bytes =
        await File('assets/files/password_manager_browser.zip').readAsBytes();
    final result = await BrowserExtensionInstaller.prepare(bytes, directory);
    expect(await File('${result.path}/manifest.json').exists(), isTrue);
    expect(await File('${result.path}/background.js').exists(), isTrue);
    expect(await File('${result.path}/icons/icon16.png').exists(), isTrue);
    final manifest =
        jsonDecode(await File('${result.path}/manifest.json').readAsString());
    expect(manifest['name'], 'Lockora 密码管理器');
    expect(manifest['version'], '3.1.0');
    expect(manifest['action']['default_title'], 'Lockora');
    expect(result.parent.path, directory.path);
    expect(result.uri.pathSegments.where((p) => p.isNotEmpty).last,
        manifest['version']);
  });

  test('rejects archive traversal before extracting any files', () async {
    final directory = await Directory.systemTemp.createTemp('pm_extension_');
    addTearDown(() => directory.delete(recursive: true));
    final archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json', '{"version":"1.0.0"}'))
      ..addFile(ArchiveFile.string('../outside.js', 'bad'));
    await expectLater(
        BrowserExtensionInstaller.prepare(
            Uint8List.fromList(ZipEncoder().encode(archive)), directory),
        throwsFormatException);
    expect(await directory.list().toList(), isEmpty);
  });
}
