import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../services/browser_extension_installer.dart';

import '../theme/internal_ui_theme.dart';

class BrowserExtensionPage extends StatefulWidget {
  const BrowserExtensionPage({Key? key}) : super(key: key);

  @override
  State<BrowserExtensionPage> createState() => _BrowserExtensionPageState();
}

class _BrowserExtensionPageState extends State<BrowserExtensionPage> {
  bool _isDownloading = false;
  String? _preparedDirectory;

  @override
  Widget build(BuildContext context) {
    return InternalUiTheme(
      child: Builder(builder: _buildPage),
    );
  }

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览器扩展'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFeatures(),
            const SizedBox(height: 24),
            _buildDownloadCard(),
            const SizedBox(height: 24),
            _buildQuickInstall(),
            const SizedBox(height: 24),
            _buildInstallSteps(),
            const SizedBox(height: 24),
            _buildUsageSteps(),
            const SizedBox(height: 24),
            _buildNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: InternalUiTheme.dialogRadius(
              context,
              darkRadius: 6,
            ),
            border: Theme.of(context).brightness == Brightness.light
                ? Border.all(color: InternalUiTokens.border, width: 2)
                : null,
          ),
          child: const Icon(
            Icons.extension,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '浏览器扩展',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '在浏览器中自动填充和保存密码',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    final features = [
      {'icon': Icons.auto_fix_high, 'title': '自动填充', 'color': Colors.blue},
      {'icon': Icons.save_outlined, 'title': '保存密码', 'color': Colors.green},
      {'icon': Icons.security, 'title': '安全可靠', 'color': Colors.orange},
      {'icon': Icons.speed, 'title': '快速便捷', 'color': Colors.purple},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '核心功能',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((feature) {
            final originalColor = feature['color'] as Color;
            final featureColor = Theme.of(context).brightness == Brightness.dark
                ? originalColor
                : Theme.of(context).colorScheme.onSurfaceVariant;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: featureColor.withValues(alpha: 0.08),
                borderRadius: InternalUiTheme.dialogRadius(
                  context,
                  darkRadius: 4,
                ),
                border: Border.all(
                  color: featureColor.withValues(alpha: 0.3),
                  width:
                      Theme.of(context).brightness == Brightness.light ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    feature['icon'] as IconData,
                    color: featureColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    feature['title'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: featureColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDownloadCard() {
    return SizedBox(
      width: double.infinity,
      child: InternalSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '下载安装包',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '支持 Chrome、Edge 等 Chromium 浏览器',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isDownloading ? null : _downloadExtension,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: InternalUiTheme.dialogRadius(
                      context,
                      darkRadius: 6,
                    ),
                    side: Theme.of(context).brightness == Brightness.light
                        ? const BorderSide(
                            color: InternalUiTokens.border,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: _isDownloading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('下载中...', style: TextStyle(fontSize: 14)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('立即下载',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noticeColor = isDark
        ? Colors.amber.shade700
        : Theme.of(context).colorScheme.onSurface;
    return InternalSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: noticeColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '使用须知',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: noticeColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '需同时运行 Lockora\n仅支持 Chromium 内核浏览器\n请勿删除解压后的文件夹',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInstall() {
    return InternalSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('快速安装', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('自动准备本应用配套的扩展文件。浏览器仍需手动开启开发者模式并选择“加载已解压的扩展程序”。'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : _prepareExtension,
            icon: const Icon(Icons.extension),
            label: Text(_isDownloading ? '正在准备…' : '一键准备扩展'),
          ),
          if (_preparedDirectory != null) ...[
            const SizedBox(height: 12),
            SelectableText(_preparedDirectory!),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: () => _openExtensionManager(false),
                  child: const Text('打开 Chrome 扩展页')),
              OutlinedButton(
                  onPressed: () => _openExtensionManager(true),
                  child: const Text('打开 Edge 扩展页')),
              TextButton(
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: _preparedDirectory!)),
                  child: const Text('复制扩展目录')),
            ]),
            const Text('在浏览器中加载以上目录即可。更新后请加载新版本目录，并移除旧版扩展。'),
          ],
        ],
      ),
    );
  }

  Future<void> _prepareExtension() async {
    setState(() => _isDownloading = true);
    try {
      final bundle =
          await rootBundle.load('assets/files/password_manager_browser.zip');
      final support = await getApplicationSupportDirectory();
      final directory = await BrowserExtensionInstaller.prepare(
        bundle.buffer.asUint8List(bundle.offsetInBytes, bundle.lengthInBytes),
        Directory('${support.path}${Platform.pathSeparator}browser_extension'),
      );
      if (!mounted) return;
      setState(() => _preparedDirectory = directory.path);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('准备扩展失败：$error')));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openExtensionManager(bool edge) async {
    final address = edge ? 'edge://extensions/' : 'chrome://extensions/';
    try {
      if (Platform.isMacOS) {
        final result = await Process.run(
            'open', ['-a', edge ? 'Microsoft Edge' : 'Google Chrome', address]);
        if (result.exitCode != 0) throw Exception('浏览器未安装');
      } else if (Platform.isWindows) {
        final result = await Process.run(
            'cmd', ['/c', 'start', '', edge ? 'msedge' : 'chrome', address]);
        if (result.exitCode != 0) throw Exception('浏览器未安装');
      } else {
        await Process.start(
            edge ? 'microsoft-edge' : 'google-chrome', [address]);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: address));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('扩展页地址已复制，请粘贴到浏览器地址栏打开')));
    }
  }

  Widget _buildInstallSteps() {
    final steps = [
      '下载并解压文件到固定位置',
      '打开浏览器扩展管理页面',
      '开启开发者模式开关',
      '点击"加载已解压的扩展程序"',
      '选择解压后的文件夹',
      '完成安装，图标出现在工具栏',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '安装步骤',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          int index = entry.key;
          String step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: InternalUiTheme.dialogRadius(
                      context,
                      darkRadius: 14,
                    ),
                    border: Theme.of(context).brightness == Brightness.light
                        ? Border.all(
                            color: InternalUiTokens.border,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      step,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildUsageSteps() {
    final usageSteps = [
      {'icon': Icons.play_arrow, 'text': '启动 Lockora'},
      {'icon': Icons.web, 'text': '访问需要登录的网站'},
      {'icon': Icons.touch_app, 'text': '点击扩展图标自动填充'},
      {'icon': Icons.save_alt, 'text': '自动提示保存新密码'},
    ];

    return InternalSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用流程',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          ...usageSteps
              .map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: InternalUiTheme.dialogRadius(
                              context,
                              darkRadius: 8,
                            ),
                            border:
                                Theme.of(context).brightness == Brightness.light
                                    ? Border.all(color: InternalUiTokens.border)
                                    : null,
                          ),
                          child: Icon(
                            step['icon'] as IconData,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step['text'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Future<void> _downloadExtension() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final byteData =
          await rootBundle.load('assets/files/password_manager_browser.zip');
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: '保存浏览器扩展',
          fileName: 'password_manager_browser.zip',
          type: FileType.any,
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                persist: false,
                content: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('扩展已下载到: ${file.path}'),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: '打开文件夹',
                  onPressed: () => _openFileLocation(file.path),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('下载失败: $e')),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _openFileLocation(String filePath) {
    final directory = File(filePath).parent.path;

    try {
      if (Platform.isWindows) {
        Process.run('explorer', [directory]);
      } else if (Platform.isMacOS) {
        Process.run('open', [directory]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [directory]);
      }
    } catch (e) {
      // debugPrint('无法打开文件夹: $e');
    }
  }
}
