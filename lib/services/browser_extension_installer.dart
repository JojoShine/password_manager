import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class BrowserExtensionInstaller {
  static Future<Directory> prepare(Uint8List bytes, Directory root) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final allowed = RegExp(
        r'^(manifest\.json|background\.js|content-script\.js|login-save-policy\.js|popup\.html|popup\.js|README\.md|icons/(app|icon16|icon32|icon48|icon128)\.png)$');
    for (final file in archive) {
      if (!file.isFile || !allowed.hasMatch(file.name)) {
        throw const FormatException('扩展包包含不支持的文件路径');
      }
    }
    final manifest = archive.findFile('manifest.json');
    if (manifest == null) throw const FormatException('扩展包缺少 manifest.json');
    final data = jsonDecode(utf8.decode(manifest.content as List<int>));
    final version = data['version'];
    if (version is! String || !RegExp(r'^\d+(\.\d+){1,3}$').hasMatch(version)) {
      throw const FormatException('扩展版本无效');
    }
    final target = Directory('${root.path}${Platform.pathSeparator}$version');
    for (final entry in archive) {
      final file = File('${target.path}${Platform.pathSeparator}${entry.name}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content as List<int>, flush: true);
    }
    return target;
  }
}
