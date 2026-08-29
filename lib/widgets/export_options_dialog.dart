import 'package:flutter/material.dart';

import '../theme/internal_ui_theme.dart';

/// 导出选项对话框
class ExportOptionsDialog extends StatefulWidget {
  const ExportOptionsDialog({super.key});

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  bool _encrypt = false;

  @override
  Widget build(BuildContext context) {
    return InternalUiTheme(
      child: Builder(builder: _buildDialog),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: InternalUiTheme.dialogShape(context),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: InternalUiTheme.dialogRadius(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.file_download_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '导出选项',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '选择密码数据的导出方式',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),

            // 明文导出选项
            InkWell(
              onTap: () {
                setState(() {
                  _encrypt = false;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: !_encrypt
                      ? colorScheme.primaryContainer
                      : isDark
                          ? colorScheme.surfaceVariant
                          : Colors.grey.shade50,
                  border: Border.all(
                    color: !_encrypt
                        ? colorScheme.primary
                        : isDark
                            ? colorScheme.outline
                            : Colors.grey.shade300,
                    width: !_encrypt ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Radio<bool>(
                      value: false,
                      groupValue: _encrypt,
                      onChanged: (value) {
                        setState(() {
                          _encrypt = value!;
                        });
                      },
                      activeColor: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.lock_open_outlined,
                      color: !_encrypt
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '明文导出',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: !_encrypt
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '导出未加密的JSON文件，可在任何支持的应用中导入',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 加密导出选项
            InkWell(
              onTap: () {
                setState(() {
                  _encrypt = true;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _encrypt
                      ? isDark
                          ? Colors.green.shade50.withOpacity(0.1)
                          : colorScheme.primaryContainer
                      : isDark
                          ? colorScheme.surfaceVariant
                          : Colors.grey.shade50,
                  border: Border.all(
                    color: _encrypt
                        ? isDark
                            ? Colors.green.shade400
                            : colorScheme.primary
                        : isDark
                            ? colorScheme.outline
                            : Colors.grey.shade300,
                    width: _encrypt ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: _encrypt,
                      onChanged: (value) {
                        setState(() {
                          _encrypt = value!;
                        });
                      },
                      activeColor:
                          isDark ? Colors.green.shade600 : colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.lock_outlined,
                      color: _encrypt
                          ? isDark
                              ? Colors.green.shade600
                              : colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '加密导出',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _encrypt
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '使用当前主密码加密导出，安全性更高',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _encrypt
                    ? isDark
                        ? Colors.green.shade50.withOpacity(0.1)
                        : InternalUiTokens.weakBackground
                    : isDark
                        ? Colors.orange.shade50.withOpacity(0.1)
                        : InternalUiTokens.weakBackground,
                border: Border.all(
                  color: _encrypt
                      ? isDark
                          ? Colors.green.shade200.withOpacity(0.5)
                          : InternalUiTokens.border
                      : isDark
                          ? Colors.orange.shade200.withOpacity(0.5)
                          : InternalUiTokens.border,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _encrypt ? Icons.info_outline : Icons.warning_outlined,
                    color: isDark
                        ? _encrypt
                            ? Colors.green.shade700
                            : Colors.orange.shade700
                        : colorScheme.onSurface,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _encrypt ? '安全提示' : '安全警告',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark
                                ? _encrypt
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _encrypt
                              ? '加密文件只能使用相同的主密码进行导入，请妥善保管您的主密码。'
                              : '明文文件包含未加密的密码信息，任何人都可以直接读取，请妥善保管。',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? _encrypt
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(ExportOptions(
                      encrypt: _encrypt,
                    ));
                  },
                  icon: Icon(
                    _encrypt ? Icons.lock : Icons.file_download,
                    size: 18,
                  ),
                  label: Text(
                    _encrypt ? '加密导出' : '导出',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark && _encrypt
                        ? Colors.green.shade600
                        : colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 导出选项数据类
class ExportOptions {
  final bool encrypt;

  const ExportOptions({
    required this.encrypt,
  });
}

/// 显示导出选项对话框
Future<ExportOptions?> showExportOptionsDialog(BuildContext context) {
  return showDialog<ExportOptions>(
    context: context,
    builder: (context) => const ExportOptionsDialog(),
  );
}
