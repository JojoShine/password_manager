import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../models/password_entry.dart';
import '../services/theme_service.dart';

/// 密码添加/编辑弹窗
class PasswordAddDialog extends StatefulWidget {
  final PasswordEntry? existingEntry; // 如果是编辑模式，传入现有条目

  const PasswordAddDialog({
    super.key,
    this.existingEntry,
  });

  @override
  State<PasswordAddDialog> createState() => _PasswordAddDialogState();
}

class _PasswordAddDialogState extends State<PasswordAddDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // 控制器
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();

  // 状态变量
  bool _obscurePassword = true;

  String _selectedCategory = '社交';

  // 自定义字段
  Map<String, dynamic> _customFields = {};

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // 从Category模型获取分类列表
  List<String> get _categories =>
      Category.predefinedCategories.map((c) => c.name).toList();

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    // 如果是编辑模式，填充现有数据
    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.title;
      _usernameController.text = widget.existingEntry!.username;
      _passwordController.text = widget.existingEntry!.password;
      _websiteController.text = widget.existingEntry!.website ?? '';
      _notesController.text = widget.existingEntry!.notes ?? '';

      _selectedCategory = widget.existingEntry!.category ?? '社交';
      _customFields =
          Map<String, dynamic>.from(widget.existingEntry!.customFields);
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 生成随机密码
  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = DateTime.now().millisecondsSinceEpoch;
    var password = '';

    for (int i = 0; i < 16; i++) {
      password += chars[(random + i) % chars.length];
    }

    setState(() {
      _passwordController.text = password;
    });

    HapticFeedback.mediumImpact();
  }

  /// 复制到剪贴板
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 已复制到剪贴板'),
        duration: const Duration(seconds: 2),
      ),
    );
    HapticFeedback.lightImpact();
  }

  /// 保存密码条目
  void _saveEntry() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final entry = PasswordEntry(
      id: widget.existingEntry?.id,
      title: _titleController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      customFields: _customFields,
      // 保留原有的收藏状态和创建时间
      isFavorite: widget.existingEntry?.isFavorite ?? false,
      category: _selectedCategory,
      createdAt: widget.existingEntry?.createdAt,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, child) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  _buildHeader(),
                  const SizedBox(height: 16),
                  // 表单内容
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTitleField(),
                            const SizedBox(height: 16),
                            _buildUsernameField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            const SizedBox(height: 16),
                            _buildWebsiteField(),
                            const SizedBox(height: 16),
                            _buildCategorySelector(),
                            const SizedBox(height: 16),
                            _buildNotesField(),
                            const SizedBox(height: 16),
                            _buildCustomFieldsSection(),
                            const SizedBox(height: 24),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            child: Icon(
              widget.existingEntry != null ? Icons.edit : Icons.add,
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
                  widget.existingEntry != null ? '编辑密码' : '添加新密码',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.existingEntry != null ? '修改密码信息' : '创建新的密码条目',
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

  /// 构建标题字段
  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: '标题 *',
        hintText: '例如：Gmail、支付宝等',
        prefixIcon: Icon(
          Icons.title,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入标题';
        }
        return null;
      },
    );
  }

  /// 构建用户名字段
  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: '用户名/邮箱 *',
        hintText: '输入用户名或邮箱地址',
        prefixIcon: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.primary,
        ),
        suffixIcon: _usernameController.text.isNotEmpty
            ? IconButton(
                onPressed: () =>
                    _copyToClipboard(_usernameController.text, '用户名'),
                icon: const Icon(Icons.copy, size: 20),
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入用户名或邮箱';
        }
        return null;
      },
      onChanged: (value) => setState(() {}),
    );
  }

  /// 构建密码字段
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码 *',
        hintText: '输入或生成密码',
        prefixIcon: Icon(
          Icons.lock,
          color: Theme.of(context).colorScheme.primary,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_passwordController.text.isNotEmpty)
              IconButton(
                onPressed: () =>
                    _copyToClipboard(_passwordController.text, '密码'),
                icon: const Icon(Icons.copy, size: 20),
              ),
            IconButton(
              onPressed: _generatePassword,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: '生成密码',
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        if (value.length < 6) {
          return '密码长度至少为6位';
        }
        return null;
      },
      onChanged: (value) => setState(() {}),
    );
  }

  /// 构建网站字段
  Widget _buildWebsiteField() {
    return TextFormField(
      controller: _websiteController,
      decoration: InputDecoration(
        labelText: '网站/应用',
        hintText: '例如：https://www.google.com',
        prefixIcon: Icon(
          Icons.language,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      keyboardType: TextInputType.url,
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
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
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
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建备注字段
  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: '备注',
        hintText: '添加额外的备注信息...',
        alignLabelWithHint: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveEntry,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(widget.existingEntry != null ? '保存' : '添加'),
          ),
        ),
      ],
    );
  }

  /// 构建自定义字段部分
  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '自定义字段',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddCustomFieldDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加字段'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_customFields.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 32,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  '还没有自定义字段',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击"添加字段"来创建自定义字段',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          ...(_customFields.entries
              .map((entry) => _buildCustomFieldItem(entry.key, entry.value))
              .toList()),
      ],
    );
  }

  /// 构建自定义字段项
  Widget _buildCustomFieldItem(String key, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.extension,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value.toString(), key),
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制$key',
          ),
          IconButton(
            onPressed: () => _editCustomField(key, value),
            icon: const Icon(Icons.edit, size: 18),
            tooltip: '编辑$key',
          ),
          IconButton(
            onPressed: () => _removeCustomField(key),
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            tooltip: '删除$key',
          ),
        ],
      ),
    );
  }

  /// 显示添加自定义字段对话框
  Future<void> _showAddCustomFieldDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CustomFieldDialog(),
    );

    if (result != null) {
      setState(() {
        _customFields[result['key']] = result['value'];
      });
    }
  }

  /// 编辑自定义字段
  Future<void> _editCustomField(String key, dynamic value) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CustomFieldDialog(
        initialKey: key,
        initialValue: value.toString(),
      ),
    );

    if (result != null) {
      setState(() {
        _customFields.remove(key); // 移除旧的键值
        _customFields[result['key']] = result['value'];
      });
    }
  }

  /// 移除自定义字段
  void _removeCustomField(String key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除自定义字段'),
        content: Text('确定要删除自定义字段"$key"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _customFields.remove(key);
              });
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 自定义字段编辑对话框
class _CustomFieldDialog extends StatefulWidget {
  final String? initialKey;
  final String? initialValue;

  const _CustomFieldDialog({
    this.initialKey,
    this.initialValue,
  });

  @override
  State<_CustomFieldDialog> createState() => _CustomFieldDialogState();
}

class _CustomFieldDialogState extends State<_CustomFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialKey != null) {
      _keyController.text = widget.initialKey!;
    }
    if (widget.initialValue != null) {
      _valueController.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = {
      'key': _keyController.text.trim(),
      'value': _valueController.text.trim(),
    };

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initialKey != null ? '编辑自定义字段' : '添加自定义字段',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: '字段名称 *',
                  hintText: '例如：身份证号、备用邮箱等',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入字段名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: '字段值 *',
                  hintText: '输入字段的值',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入字段值';
                  }
                  return null;
                },
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(widget.initialKey != null ? '保存' : '添加'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
