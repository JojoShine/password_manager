import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/settings_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
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
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置Logo失败: $e'),
            backgroundColor: Colors.red,
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
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置背景图片失败: $e'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置Logo失败: $e'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置背景图片失败: $e'),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存应用标题失败: $e'),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final timeout = int.tryParse(timeoutText);
    if (timeout == null || timeout < 1 || timeout > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('锁定时间必须是1-1440分钟之间的数字'),
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存锁定时间失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

                const SizedBox(height: 20),

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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
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

                const SizedBox(height: 20),

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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
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

                const SizedBox(height: 20),

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
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建设置区块卡片
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
