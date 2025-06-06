import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../models/password_entry.dart';

class PasswordGeneratorDialog extends StatefulWidget {
  const PasswordGeneratorDialog({super.key});

  @override
  State<PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  // 密码生成配置
  double _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  bool _excludeSimilar = true;

  // 生成的密码
  String _generatedPassword = '';

  // 表单控制器
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = '常用';

  // 字符集
  static const String _uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String _numberChars = '0123456789';
  static const String _symbolChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  static const String _similarChars = 'il1Lo0O';

  final List<String> _categories = [
    '常用',
    ...Category.predefinedCategories.map((c) => c.name),
  ];

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// 生成密码
  void _generatePassword() {
    if (!_includeUppercase &&
        !_includeLowercase &&
        !_includeNumbers &&
        !_includeSymbols) {
      setState(() {
        _generatedPassword = '请至少选择一种字符类型';
      });
      return;
    }

    String chars = '';
    if (_includeUppercase) chars += _uppercaseChars;
    if (_includeLowercase) chars += _lowercaseChars;
    if (_includeNumbers) chars += _numberChars;
    if (_includeSymbols) chars += _symbolChars;

    // 排除相似字符
    if (_excludeSimilar) {
      for (String char in _similarChars.split('')) {
        chars = chars.replaceAll(char, '');
      }
    }

    final random = Random.secure();
    final password = List.generate(
      _length.toInt(),
      (index) => chars[random.nextInt(chars.length)],
    ).join();

    setState(() {
      _generatedPassword = password;
    });
  }

  /// 复制到剪贴板
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label已复制到剪贴板'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 保存为密码条目
  void _saveAsEntry() {
    if (_generatedPassword.isEmpty || _generatedPassword == '请至少选择一种字符类型') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先生成有效密码'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写标题和用户名'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final entry = PasswordEntry(
      title: _titleController.text.trim(),
      username: _usernameController.text.trim(),
      password: _generatedPassword,
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      category: _selectedCategory,
    );

    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(),
            // 内容区域 - 使用两列布局
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧：密码生成配置
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildGeneratorConfig(),
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordDisplay(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // 右侧：保存选项
                    Expanded(
                      flex: 2,
                      child: _buildSaveOptions(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.generating_tokens,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '密码生成器',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '生成安全的随机密码',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建生成器配置
  Widget _buildGeneratorConfig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '密码配置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // 长度选择
          Text(
            '密码长度: ${_length.toInt()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Slider(
            value: _length,
            min: 6,
            max: 50,
            divisions: 44,
            onChanged: (value) {
              setState(() {
                _length = value;
              });
              _generatePassword();
            },
          ),
          const SizedBox(height: 8),

          // 字符类型选择
          Text(
            '包含字符类型',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // 字符类型选项 - 可滚动区域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCharacterTypeOption('大写字母 (A-Z)', _includeUppercase,
                      (value) {
                    setState(() => _includeUppercase = value);
                    _generatePassword();
                  }),
                  _buildCharacterTypeOption('小写字母 (a-z)', _includeLowercase,
                      (value) {
                    setState(() => _includeLowercase = value);
                    _generatePassword();
                  }),
                  _buildCharacterTypeOption('数字 (0-9)', _includeNumbers,
                      (value) {
                    setState(() => _includeNumbers = value);
                    _generatePassword();
                  }),
                  _buildCharacterTypeOption('特殊符号 (!@#\$%^&*)', _includeSymbols,
                      (value) {
                    setState(() => _includeSymbols = value);
                    _generatePassword();
                  }),
                  _buildCharacterTypeOption('排除相似字符 (il1Lo0O)', _excludeSimilar,
                      (value) {
                    setState(() => _excludeSimilar = value);
                    _generatePassword();
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建字符类型选项
  Widget _buildCharacterTypeOption(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建密码显示
  Widget _buildPasswordDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '生成的密码',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _generatePassword,
                    icon: const Icon(Icons.refresh),
                    tooltip: '重新生成',
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(_generatedPassword, '密码'),
                    icon: const Icon(Icons.copy),
                    tooltip: '复制密码',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: SelectableText(
              _generatedPassword,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPasswordStrength(),
        ],
      ),
    );
  }

  /// 构建密码强度指示器
  Widget _buildPasswordStrength() {
    int strength = _calculatePasswordStrength();
    String strengthText = '';
    Color strengthColor = Colors.red;

    switch (strength) {
      case 0:
      case 1:
        strengthText = '弱';
        strengthColor = Colors.red;
        break;
      case 2:
        strengthText = '中等';
        strengthColor = Colors.orange;
        break;
      case 3:
        strengthText = '强';
        strengthColor = Colors.lightGreen;
        break;
      case 4:
        strengthText = '很强';
        strengthColor = Colors.green;
        break;
    }

    return Row(
      children: [
        Text(
          '密码强度: ',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          strengthText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: strengthColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: strength / 4,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
          ),
        ),
      ],
    );
  }

  /// 计算密码强度
  int _calculatePasswordStrength() {
    if (_generatedPassword.isEmpty || _generatedPassword == '请至少选择一种字符类型')
      return 0;

    int score = 0;
    if (_generatedPassword.length >= 12) score++;
    if (_includeUppercase && _generatedPassword.contains(RegExp(r'[A-Z]')))
      score++;
    if (_includeLowercase && _generatedPassword.contains(RegExp(r'[a-z]')))
      score++;
    if (_includeNumbers && _generatedPassword.contains(RegExp(r'[0-9]')))
      score++;
    if (_includeSymbols &&
        _generatedPassword
            .contains(RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score++;

    return score > 4 ? 4 : score;
  }

  /// 构建保存选项
  Widget _buildSaveOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.save,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '直接保存为密码条目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 表单字段
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 标题字段
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: '标题 *',
                      hintText: '例如：Gmail、支付宝等',
                      prefixIcon: Icon(
                        Icons.title,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 用户名字段
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '用户名/邮箱 *',
                      hintText: '输入用户名或邮箱地址',
                      prefixIcon: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 网站字段
                  TextFormField(
                    controller: _websiteController,
                    decoration: InputDecoration(
                      labelText: '网站/应用',
                      hintText: '例如：https://www.google.com',
                      prefixIcon: Icon(
                        Icons.language,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),

                  // 分类选择
                  _buildCategorySelector(),
                  const SizedBox(height: 12),

                  // 备注字段
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: '备注',
                      hintText: '添加额外的备注信息...',
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveAsEntry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('保存密码'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建分类选择器
  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
