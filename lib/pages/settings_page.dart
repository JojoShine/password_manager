import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/event_bus.dart';
import '../services/secure_storage_service.dart';
import '../services/settings_service.dart';
import '../theme/internal_ui_theme.dart';
import '../widgets/app_update_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();

  bool _isLogoLoading = false;
  bool _isBackgroundLoading = false;
  late Future<String> _dataLocationFuture;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _dataLocationFuture =
        SecureStorageService.instance.getPasswordDataLocation();
  }

  void _initializeControllers() {
    _titleController.text = SettingsService.instance.appTitle;
    _timeoutController.text =
        SettingsService.instance.lockTimeoutMinutes.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  /// 选择并设置logo
  Future<void> _selectLogo() async {
    setState(() => _isLogoLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await SettingsService.instance.setCustomLogo(result.files.single.path!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logo设置成功！'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置Logo失败: $e'),
          ),
        );
      }
    } finally {
      setState(() => _isLogoLoading = false);
    }
  }

  /// 选择并设置背景图片
  Future<void> _selectBackground() async {
    setState(() => _isBackgroundLoading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await SettingsService.instance
            .setCustomBackground(result.files.single.path!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('背景图片设置成功！'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置背景图片失败: $e'),
          ),
        );
      }
    } finally {
      setState(() => _isBackgroundLoading = false);
    }
  }

  /// 重置logo为默认
  Future<void> _resetLogo() async {
    try {
      await SettingsService.instance.resetLogo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo已重置为默认'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置Logo失败: $e'),
          ),
        );
      }
    }
  }

  /// 重置背景为默认
  Future<void> _resetBackground() async {
    try {
      await SettingsService.instance.resetBackground();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('背景图片已重置为默认'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置背景图片失败: $e'),
          ),
        );
      }
    }
  }

  /// 保存应用标题
  Future<void> _saveTitle() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('应用标题不能为空'),
        ),
      );
      return;
    }

    try {
      await SettingsService.instance.setAppTitle(title);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('应用标题保存成功！'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存应用标题失败: $e'),
          ),
        );
      }
    }
  }

  /// 保存锁定超时时间
  Future<void> _saveTimeout() async {
    final timeoutText = _timeoutController.text.trim();
    if (timeoutText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('锁定时间不能为空'),
        ),
      );
      return;
    }

    final timeout = int.tryParse(timeoutText);
    if (timeout == null || timeout < 1 || timeout > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('锁定时间必须是1-1440分钟之间的数字'),
        ),
      );
      return;
    }

    try {
      await SettingsService.instance.setLockTimeout(timeout);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('锁定时间保存成功！'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存锁定时间失败: $e'),
          ),
        );
      }
    }
  }

  // /// 显示认证状态信息
  // Future<void> _showAuthStatus() async {
  //   try {
  //     final authService = AuthService.instance;
  //     final needsAuth = await authService.needsAuthentication();
  //     final settings = await authService.getCurrentSettings();
  //     final timeoutMinutes = SettingsService.instance.lockTimeoutMinutes;

  //     if (mounted) {
  //       showDialog(
  //         context: context,
  //         builder: (context) => AlertDialog(
  //           title: const Text('认证状态信息'),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text('需要重新认证: ${needsAuth ? "是" : "否"}',
  //                   style: TextStyle(
  //                       color: needsAuth ? Colors.red : Colors.green,
  //                       fontWeight: FontWeight.bold)),
  //               const SizedBox(height: 8),
  //               Text('锁定超时时间: $timeoutMinutes 分钟'),
  //               const SizedBox(height: 8),
  //               Text(
  //                   '当前时间: ${DateTime.now().toLocal().toString().substring(0, 19)}',
  //                   style: const TextStyle(fontSize: 12)),
  //               const SizedBox(height: 8),
  //               if (settings.lastUnlockTime != null) ...[
  //                 Text(
  //                     '最后解锁时间: ${settings.lastUnlockTime!.toLocal().toString().substring(0, 19)}',
  //                     style: const TextStyle(fontSize: 12)),
  //                 const SizedBox(height: 8),
  //                 Text(
  //                     '距上次解锁: ${DateTime.now().difference(settings.lastUnlockTime!).inMinutes} 分钟 (${DateTime.now().difference(settings.lastUnlockTime!).inSeconds} 秒)',
  //                     style: TextStyle(
  //                         color: Colors.orange, fontWeight: FontWeight.bold)),
  //               ] else
  //                 const Text('未记录解锁时间', style: TextStyle(color: Colors.red)),
  //               const SizedBox(height: 8),
  //               Text('是否首次启动: ${settings.isFirstLaunch ? "是" : "否"}'),
  //               const SizedBox(height: 8),
  //               Text('是否设置主密码: ${settings.hasMasterPassword ? "是" : "否"}'),
  //               const SizedBox(height: 16),
  //               Container(
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: Colors.blue.withOpacity(0.1),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Text('锁定逻辑说明:',
  //                         style: TextStyle(fontWeight: FontWeight.bold)),
  //                     const SizedBox(height: 4),
  //                     const Text('• 每次验证主密码后更新"最后解锁时间"',
  //                         style: TextStyle(fontSize: 12)),
  //                     const Text('• 应用启动时检查距离上次解锁是否超过设定时间',
  //                         style: TextStyle(fontSize: 12)),
  //                     const Text('• 超过时间则要求重新输入密码',
  //                         style: TextStyle(fontSize: 12)),
  //                     if (settings.lastUnlockTime != null && timeoutMinutes > 0)
  //                       Text(
  //                           '• 当前将在 ${settings.lastUnlockTime!.add(Duration(minutes: timeoutMinutes)).toLocal().toString().substring(0, 19)} 后锁定',
  //                           style: const TextStyle(
  //                               fontSize: 12, color: Colors.red)),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(),
  //               child: const Text('确定'),
  //             ),
  //           ],
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('获取认证状态失败: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return InternalUiTheme(
      child: Builder(builder: _buildPage),
    );
  }

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用设置'),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: SettingsService.instance,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 应用标题设置
                _buildSectionCard(
                  title: '应用标题',
                  icon: Icons.title,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '应用标题',
                          hintText: '请输入应用标题',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLength: 50,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveTitle,
                          icon: const Icon(Icons.save),
                          label: const Text('保存标题'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Logo设置
                _buildSectionCard(
                  title: 'Logo设置',
                  icon: Icons.image,
                  child: Column(
                    children: [
                      // 当前logo预览
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: InternalUiTheme.dialogRadius(
                            context,
                            darkRadius: 6,
                          ),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: InternalUiTheme.dialogRadius(
                            context,
                            darkRadius: 5,
                          ),
                          child: _buildLogoImage(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        SettingsService.instance.hasCustomLogo
                            ? '当前使用：自定义Logo'
                            : '当前使用：默认Logo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLogoLoading ? null : _selectLogo,
                              icon: _isLogoLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload),
                              label: const Text('选择Logo'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: SettingsService.instance.hasCustomLogo
                                  ? _resetLogo
                                  : null,
                              icon: const Icon(Icons.restore),
                              label: const Text('重置默认'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 背景图片设置
                _buildSectionCard(
                  title: '背景图片设置',
                  icon: Icons.wallpaper,
                  child: Column(
                    children: [
                      // 当前背景预览
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: InternalUiTheme.dialogRadius(
                            context,
                            darkRadius: 6,
                          ),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: InternalUiTheme.dialogRadius(
                            context,
                            darkRadius: 5,
                          ),
                          child: _buildBackgroundImage(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        SettingsService.instance.hasCustomBackground
                            ? '当前使用：自定义背景'
                            : '当前使用：默认背景',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isBackgroundLoading
                                  ? null
                                  : _selectBackground,
                              icon: _isBackgroundLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload),
                              label: const Text('选择背景'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  SettingsService.instance.hasCustomBackground
                                      ? _resetBackground
                                      : null,
                              icon: const Icon(Icons.restore),
                              label: const Text('重置默认'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 锁定时间设置
                _buildSectionCard(
                  title: '自动锁定时间',
                  icon: Icons.lock_clock,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _timeoutController,
                        decoration: const InputDecoration(
                          labelText: '锁定时间（分钟）',
                          hintText: '请输入1-1440之间的数字',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixText: '分钟',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '应用在后台运行超过设定时间后将自动锁定\n默认为30分钟，最大为1440分钟（24小时）',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveTimeout,
                          icon: const Icon(Icons.save),
                          label: const Text('保存设置'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const AppUpdateSection(),
                const SizedBox(height: 24),
                _buildDataAndApplicationSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataAndApplicationSection() {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    return _buildSectionCard(
      title: '数据与应用',
      icon: Icons.storage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '密码数据存放位置',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          PixelPanel(
            child: FutureBuilder<String>(
              future: _dataLocationFuture,
              builder: (context, snapshot) => SelectableText(
                snapshot.data ?? (snapshot.hasError ? '无法获取数据目录' : '正在读取…'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openDataDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('打开数据目录'),
              ),
            ),
          ],
          if (isDesktop) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _changeDataDirectory,
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Text('更改密码存储位置'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _useExistingPasswordDirectory,
                icon: const Icon(Icons.folder_shared_outlined),
                label: const Text('使用已有密码库'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '可选择 iCloud Drive 等同步目录。第二台设备请选择“使用已有密码库”。'
              '文件为明文，请妥善管理目录权限；云盘同步有延迟，请避免多设备同时编辑。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '重置只会清除密码记录和备份，不会删除主密码、主题、Logo、背景或锁定时间。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmResetPasswords,
              icon: const Icon(Icons.delete_forever),
              label: const Text('一键重置密码数据'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showUninstallGuide,
              icon: const Icon(Icons.unarchive_outlined),
              label: const Text('应用卸载流程'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDataDirectory() async {
    try {
      await SecureStorageService.instance.openPasswordDataLocation();
    } catch (error) {
      _showMessage('打开数据目录失败：$error');
    }
  }

  Future<void> _changeDataDirectory() async {
    try {
      final selectedRoot = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择密码数据存放位置',
        lockParentWindow: true,
      );
      if (selectedRoot == null || selectedRoot.trim().isEmpty) return;

      final location = await SecureStorageService.instance
          .changePasswordDataRoot(selectedRoot);
      if (!mounted) return;
      setState(() {
        _dataLocationFuture = Future.value(location);
      });
      _showMessage('密码数据已迁移到新位置');
    } catch (error) {
      _showMessage('更改密码存储位置失败：$error');
    }
  }

  Future<void> _useExistingPasswordDirectory() async {
    try {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择包含 passwords.json 的密码库目录',
        lockParentWindow: true,
      );
      if (directory == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('切换到已有密码库？'),
          content: const Text('将显示所选目录中的密码。当前密码库保留在原位置，不会合并或覆盖。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('切换')),
          ],
        ),
      );
      if (confirmed != true) return;
      final location = await SecureStorageService.instance
          .useExistingPasswordDirectory(directory);
      if (!mounted) return;
      setState(() => _dataLocationFuture = Future.value(location));
      _showMessage('已切换密码库');
    } catch (error) {
      _showMessage('切换密码库失败：$error');
    }
  }

  Future<void> _confirmResetPasswords() async {
    try {
      final count = await SecureStorageService.instance.countPasswords();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .55),
        builder: (dialogContext) => InternalUiTheme(
          child: Dialog(
            shape: InternalUiTheme.dialogShape(dialogContext),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelDialogHeader(
                    title: '重置密码数据',
                    subtitle: '此操作不可撤销',
                    icon: Icons.warning_amber,
                    color: Theme.of(dialogContext).colorScheme.error,
                    onClose: () => Navigator.of(dialogContext).pop(false),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        PixelPanel(
                          child: Text(
                            '将永久清除 $count 条密码记录及其备份。\n\n主密码和界面设置会保留。',
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(dialogContext).colorScheme.error,
                                  foregroundColor: Theme.of(dialogContext)
                                      .colorScheme
                                      .onError,
                                ),
                                child: const Text('确认清除'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;
      await SecureStorageService.instance.clearPasswords();
      EventBus.instance.emitPasswordDataChanged();
      _showMessage('本地密码记录已全部清除');
    } catch (error) {
      _showMessage('清除密码数据失败：$error');
    }
  }

  Future<void> _showUninstallGuide() async {
    final instructions = _uninstallInstructions();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (dialogContext) => InternalUiTheme(
        child: Dialog(
          shape: InternalUiTheme.dialogShape(dialogContext),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixelDialogHeader(
                  title: '应用卸载流程',
                  subtitle: _platformName,
                  icon: Icons.unarchive_outlined,
                  onClose: () => Navigator.of(dialogContext).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '卸载不会自动删除本地数据。',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      PixelPanel(
                        child: Text(instructions,
                            style: const TextStyle(height: 1.7)),
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _openDataDirectory,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('打开数据目录'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _revealApplication,
                          icon: const Icon(Icons.apps),
                          label: const Text('打开应用所在位置'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('我知道了'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _uninstallInstructions() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return '1. 如需彻底清理，先使用“一键重置密码数据”。\n'
            '2. 退出 Lockora。\n'
            '3. 在访达中将 Lockora.app 移到废纸篓。\n'
            '4. 如需移除其他设置，可删除上方数据目录。';
      case TargetPlatform.windows:
        return '1. 如需彻底清理，先使用“一键重置密码数据”。\n'
            '2. 退出 Lockora。\n'
            '3. 打开“设置 > 应用 > 已安装的应用”。\n'
            '4. 找到 Lockora 并选择“卸载”。\n'
            '5. 如需移除其他设置，可删除上方数据目录。';
      case TargetPlatform.linux:
        return '1. 如需彻底清理，先使用“一键重置密码数据”。\n'
            '2. 退出 Lockora。\n'
            '3. 删除 AppImage，或通过所用软件包管理器卸载。\n'
            '4. 如需移除其他设置，可删除上方数据目录。';
      default:
        return '1. 先清空密码数据。\n2. 从当前平台卸载或移除应用。';
    }
  }

  String get _platformName {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Future<void> _revealApplication() async {
    try {
      ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run('open', ['-R', Platform.resolvedExecutable]);
      } else if (Platform.isWindows) {
        result = await Process.run(
          'explorer',
          ['/select,${Platform.resolvedExecutable}'],
        );
      } else {
        result = await Process.run(
          'xdg-open',
          [File(Platform.resolvedExecutable).parent.path],
        );
      }
      if (result.exitCode != 0) throw Exception('系统未能打开应用位置');
    } catch (error) {
      _showMessage('打开应用位置失败：$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 构建设置区块卡片
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return InternalSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: InternalUiTheme.dialogRadius(
                    context,
                    darkRadius: 6,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  /// 构建Logo图片显示
  Widget _buildLogoImage() {
    final logoPath = SettingsService.instance.getLogoImagePath();

    if (SettingsService.instance.hasCustomLogo) {
      // 显示自定义logo
      return Image.file(
        File(logoPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.primary,
            child: const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 32,
            ),
          );
        },
      );
    } else {
      // 显示默认logo
      return Image.asset(
        logoPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.primary,
            child: const Icon(
              Icons.security,
              color: Colors.white,
              size: 32,
            ),
          );
        },
      );
    }
  }

  /// 构建背景图片显示
  Widget _buildBackgroundImage() {
    final backgroundPath = SettingsService.instance.getBackgroundImagePath();

    if (SettingsService.instance.hasCustomBackground) {
      // 显示自定义背景
      return Image.file(
        File(backgroundPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              size: 32,
            ),
          );
        },
      );
    } else {
      // 显示默认背景
      return Image.asset(
        backgroundPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: Icon(
              Icons.wallpaper,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              size: 32,
            ),
          );
        },
      );
    }
  }
}
