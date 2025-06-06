# 密码管理器数据库使用指南

本项目使用SQLite数据库来存储密码条目和自定义字段模板，支持灵活的自定义字段扩展功能。

## 目录结构

```
lib/
├── db/
│   └── database_helper.dart          # 数据库助手类
├── models/
│   ├── password_entry.dart           # 密码条目模型
│   └── custom_field_template.dart    # 自定义字段模板模型
├── services/
│   ├── password_service.dart         # 密码服务类
│   └── custom_field_service.dart     # 自定义字段服务类
└── examples/
    └── database_usage_example.dart   # 使用示例
```

## 数据库表结构

### 1. password_entries 表（密码条目）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| title | TEXT | 标题（必填） |
| username | TEXT | 用户名（必填） |
| password | TEXT | 密码（必填） |
| website | TEXT | 网站地址 |
| notes | TEXT | 备注 |
| custom_fields | TEXT | 自定义字段（JSON格式） |
| created_at | TEXT | 创建时间 |
| updated_at | TEXT | 更新时间 |
| is_favorite | INTEGER | 是否收藏（0/1） |
| category | TEXT | 分类 |
| icon_url | TEXT | 图标URL |

### 2. custom_field_templates 表（自定义字段模板）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| name | TEXT | 字段名称（唯一） |
| label | TEXT | 显示标签 |
| type | TEXT | 字段类型 |
| is_required | INTEGER | 是否必填（0/1） |
| default_value | TEXT | 默认值 |
| options | TEXT | 选项（用于下拉选择） |
| placeholder | TEXT | 占位符 |
| description | TEXT | 描述 |
| created_at | TEXT | 创建时间 |
| updated_at | TEXT | 更新时间 |

### 3. categories 表（分类）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| name | TEXT | 分类名称（唯一） |
| color | TEXT | 分类颜色 |
| icon | TEXT | 分类图标 |
| created_at | TEXT | 创建时间 |
| updated_at | TEXT | 更新时间 |

## 支持的自定义字段类型

| 类型 | 说明 | 验证规则 |
|------|------|----------|
| text | 文本 | 无特殊验证 |
| email | 邮箱 | 邮箱格式验证 |
| url | 网址 | URL格式验证 |
| phone | 电话 | 电话号码格式验证 |
| number | 数字 | 数字格式验证 |
| date | 日期 | 日期格式验证 |
| password | 密码 | 无特殊验证（隐藏显示） |
| multiline | 多行文本 | 无特殊验证 |
| boolean | 是/否 | 布尔值验证 |
| select | 下拉选择 | 选项范围验证 |

## 基本使用方法

### 1. 创建密码条目

```dart
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/services/password_service.dart';

// 创建一个基本的密码条目
final passwordEntry = PasswordEntry(
  title: '微信',
  username: 'user@example.com',
  password: 'StrongPassword123!',
  website: 'https://weixin.qq.com',
  notes: '个人微信账号',
  category: '社交媒体',
  isFavorite: true,
);

// 保存到数据库
final passwordService = PasswordService.instance;
final id = await passwordService.createPasswordEntry(passwordEntry);
```

### 2. 添加自定义字段

```dart
// 创建带有自定义字段的密码条目
final passwordEntry = PasswordEntry(
  title: '银行账户',
  username: 'account123',
  password: 'BankPassword456!',
  category: '银行金融',
  customFields: {
    'security_question': '您的母亲姓名？',
    'security_answer': '李女士',
    'phone_number': '+86 138 0000 0000',
    'account_type': '储蓄卡',
    'expiry_date': '2025-12-31',
  },
);

await passwordService.createPasswordEntry(passwordEntry);
```

### 3. 查询密码条目

```dart
// 获取所有密码条目
final allEntries = await passwordService.getAllPasswordEntries();

// 搜索密码条目
final searchResults = await passwordService.searchPasswordEntries('微信');

// 根据分类查询
final socialMediaEntries = await passwordService.getPasswordEntriesByCategory('社交媒体');

// 获取收藏的条目
final favoriteEntries = await passwordService.getFavoritePasswordEntries();

// 根据ID获取特定条目
final entry = await passwordService.getPasswordEntry(1);
```

### 4. 更新密码条目

```dart
// 获取要更新的条目
final entry = await passwordService.getPasswordEntry(1);
if (entry != null) {
  // 更新基本信息
  final updatedEntry = entry.copyWith(
    password: 'NewPassword123!',
    notes: '更新后的备注',
  );
  
  // 添加新的自定义字段
  final entryWithCustomField = updatedEntry.addCustomField('backup_email', 'backup@example.com');
  
  // 保存更新
  await passwordService.updatePasswordEntry(entryWithCustomField);
}
```

### 5. 创建自定义字段模板

```dart
import 'package:password_manager/models/custom_field_template.dart';
import 'package:password_manager/services/custom_field_service.dart';

final template = CustomFieldTemplate(
  name: 'license_key',
  label: '授权密钥',
  type: CustomFieldType.password,
  isRequired: false,
  placeholder: '输入软件授权密钥',
  description: '软件或服务的授权密钥',
);

final customFieldService = CustomFieldService.instance;
final id = await customFieldService.createCustomFieldTemplate(template);
```

### 6. 字段验证

```dart
// 验证自定义字段值
final fieldValues = {
  'backup_email': 'user@example.com',
  'phone_number': '+86 138 0000 0000',
  'account_type': '高级',
};

final errors = await customFieldService.validateFieldValues(fieldValues);
if (errors.isNotEmpty) {
  // 处理验证错误
  errors.forEach((field, error) {
    print('$field: $error');
  });
}
```

## 高级功能

### 1. 批量操作

```dart
// 批量删除密码条目
final idsToDelete = [1, 2, 3];
await passwordService.deletePasswordEntries(idsToDelete);

// 复制密码条目
final duplicatedId = await passwordService.duplicatePasswordEntry(1);
```

### 2. 统计信息

```dart
// 获取密码条目统计
final stats = await passwordService.getPasswordEntryStats();
print('总条目数：${stats['total']}');
print('收藏条目数：${stats['favorites']}');

// 获取自定义字段模板统计
final templateStats = await customFieldService.getCustomFieldTemplateStats();
print('模板总数：${templateStats['total']}');
```

### 3. 数据导出

```dart
// 导出所有密码条目
final exportData = await passwordService.exportPasswordEntries();

// 导出自定义字段模板
final templateExportData = await customFieldService.exportCustomFieldTemplates();
```

## 默认数据

### 默认分类
- 社交媒体 (蓝色)
- 邮箱 (红色)
- 银行金融 (绿色)
- 工作 (琥珀色)
- 购物 (紫色)
- 其他 (灰色)

### 默认自定义字段模板
- 安全问题 (文本)
- 安全答案 (文本)
- 备用邮箱 (邮箱)
- 手机号码 (电话)
- 双因子认证密钥 (密码)
- 账户类型 (下拉选择)
- 到期日期 (日期)

## 最佳实践

### 1. 数据安全
- 密码存储前应进行加密
- 敏感的自定义字段（如安全答案）也应加密存储
- 考虑实现数据库文件加密

### 2. 性能优化
- 使用索引提高查询性能
- 对于大量数据，考虑分页查询
- 定期清理不需要的数据

### 3. 用户体验
- 提供搜索和过滤功能
- 实现收藏和分类管理
- 支持批量操作

### 4. 数据备份
- 定期备份数据库文件
- 提供数据导出功能
- 考虑云端同步功能

## 故障排除

### 1. 数据库初始化失败
检查文件权限和存储空间是否足够。

### 2. 字段验证失败
确保自定义字段值符合相应类型的格式要求。

### 3. 查询性能问题
检查是否正确使用了索引，考虑优化查询语句。

## 扩展开发

### 1. 添加新的字段类型
在 `CustomFieldType` 枚举中添加新类型，并在验证逻辑中添加相应处理。

### 2. 增加新的数据表
在 `DatabaseHelper` 的 `_onCreate` 方法中添加新表的创建语句。

### 3. 实现数据迁移
在 `_onUpgrade` 方法中处理数据库版本升级逻辑。

## 示例代码

完整的使用示例请参考 `lib/examples/database_usage_example.dart` 文件。 