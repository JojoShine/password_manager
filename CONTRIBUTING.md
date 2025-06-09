# 🤝 贡献指南 (Contributing Guide)

感谢您对密码管理器项目的关注！我们欢迎所有形式的贡献，包括但不限于代码贡献、问题报告、功能建议、文档改进和社区支持。

## 📋 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
- [开发环境设置](#开发环境设置)
- [提交规范](#提交规范)
- [代码审查流程](#代码审查流程)
- [问题报告](#问题报告)
- [功能建议](#功能建议)

## 🎯 行为准则

参与本项目时，请遵守我们的 [行为准则](CODE_OF_CONDUCT.md)。我们致力于营造一个开放、友好的社区环境。

## 🛠️ 如何贡献

### 代码贡献

1. **Fork 仓库**
   ```bash
   # 在GitHub上点击Fork按钮
   ```

2. **克隆到本地**
   ```bash
   git clone https://github.com/YOUR_USERNAME/password_manager.git
   cd password_manager
   ```

3. **创建功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   # 或者
   git checkout -b fix/issue-number
   ```

4. **进行开发**
   - 遵循项目的代码规范
   - 添加必要的测试
   - 更新相关文档

5. **提交更改**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

6. **推送分支**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **创建 Pull Request**
   - 在GitHub上创建PR
   - 详细描述更改内容
   - 关联相关Issue

### 非代码贡献

- **文档改进**: 修正错别字、改进说明、翻译文档
- **问题报告**: 报告Bug或提出改进建议
- **设计贡献**: UI/UX设计建议和改进
- **测试**: 帮助测试新功能和修复
- **社区支持**: 在Issues中帮助其他用户

## 🔧 开发环境设置

### 前置要求

- **Flutter SDK**: 3.22.0 或更高版本
- **Dart SDK**: 3.2.6 或更高版本
- **IDE**: VS Code 或 Android Studio（推荐）
- **Git**: 版本控制工具

### 环境配置

1. **安装Flutter**
   ```bash
   # 参考官方文档: https://docs.flutter.dev/get-started/install
   flutter doctor  # 检查环境配置
   ```

2. **安装项目依赖**
   ```bash
   flutter pub get
   ```

3. **配置IDE**
   - 安装Flutter和Dart插件
   - 配置代码格式化工具
   - 设置调试配置

4. **运行项目**
   ```bash
   # 桌面版
   flutter run -d macos     # macOS
   flutter run -d windows   # Windows
   flutter run -d linux     # Linux
   
   # 移动版
   flutter run -d android   # Android
   ```

### 项目结构

```
lib/
├── models/              # 数据模型
│   ├── password_entry.dart
│   ├── category.dart
│   └── app_settings.dart
├── services/            # 业务服务层
│   ├── storage_service.dart
│   ├── encryption_service.dart
│   ├── backup_service.dart
│   └── security_service.dart
├── pages/               # 页面UI
│   ├── home/
│   ├── settings/
│   ├── password_form/
│   └── auth/
├── widgets/             # 通用组件
│   ├── common/
│   ├── forms/
│   └── dialogs/
├── utils/               # 工具函数
│   ├── constants.dart
│   ├── validators.dart
│   └── helpers.dart
└── main.dart            # 应用入口
```

## 📝 提交规范

我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

### 提交类型

- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码格式化（不影响代码逻辑）
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

### 提交格式

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### 示例

```bash
feat(auth): add biometric authentication support

Add Touch ID and Face ID support for quick app unlock.
This feature is available on supported devices and can be
enabled in the security settings.

Closes #123
```

```bash
fix(storage): prevent data corruption on app crash

- Add transaction-like behavior to data saves
- Implement backup file creation before writes
- Add integrity checks after data operations

Fixes #456
```

## 🔍 代码审查流程

### Pull Request 要求

1. **描述清晰**: 详细说明更改内容和原因
2. **测试完整**: 包含单元测试和集成测试
3. **文档更新**: 更新相关文档和注释
4. **代码质量**: 通过静态分析检查
5. **功能演示**: 提供截图或视频（如适用）

### 审查标准

- **功能性**: 代码是否按预期工作
- **安全性**: 是否引入安全风险
- **性能**: 是否影响应用性能
- **兼容性**: 是否保持向后兼容
- **代码质量**: 是否遵循项目规范
- **测试覆盖**: 是否有足够的测试

### 审查流程

1. **自动检查**: CI/CD流水线自动运行测试
2. **代码审查**: 维护者进行代码审查
3. **讨论修改**: 根据反馈进行修改
4. **最终批准**: 通过所有检查后合并

## 🐛 问题报告

### 报告Bug

使用我们的 [Bug报告模板](.github/ISSUE_TEMPLATE/bug_report.md)，包含：

- **环境信息**: 操作系统、Flutter版本等
- **问题描述**: 清晰描述问题现象
- **复现步骤**: 详细的复现步骤
- **预期行为**: 期望的正确行为
- **实际行为**: 实际发生的错误行为
- **截图/日志**: 相关截图或错误日志

### 示例Bug报告

```markdown
## 问题描述
在添加新密码时，如果密码长度超过100个字符，应用会崩溃。

## 环境信息
- 操作系统: macOS 14.0
- Flutter版本: 3.22.0
- 应用版本: 1.0.3

## 复现步骤
1. 打开应用
2. 点击"添加密码"
3. 输入超过100个字符的密码
4. 点击保存
5. 应用崩溃

## 预期行为
应用应该正常保存密码或显示长度限制提示。

## 实际行为
应用直接崩溃并退出。
```

## 💡 功能建议

使用我们的 [功能请求模板](.github/ISSUE_TEMPLATE/feature_request.md)，包含：

- **功能描述**: 详细描述建议的功能
- **使用场景**: 说明功能的应用场景
- **解决方案**: 提出可能的实现方案
- **替代方案**: 列出其他可能的解决方法
- **相关资料**: 提供相关的参考资料

## 📚 开发指南

### 代码规范

1. **Dart代码**: 遵循 [Dart Style Guide](https://dart.dev/guides/language/effective-dart)
2. **命名规范**: 
   - 类名: PascalCase (`PasswordEntry`)
   - 方法/变量: camelCase (`getUserName`)
   - 常量: UPPER_SNAKE_CASE (`MAX_PASSWORD_LENGTH`)
   - 文件名: snake_case (`password_service.dart`)

3. **注释规范**:
   ```dart
   /// 加密用户密码数据
   /// 
   /// [data] 要加密的原始数据
   /// [key] 加密密钥
   /// 
   /// 返回加密后的数据，如果加密失败返回null
   String? encryptPassword(String data, String key) {
     // 实现细节...
   }
   ```

### 测试规范

1. **单元测试**: 测试单个函数或类
   ```dart
   test('should encrypt password correctly', () {
     final result = encryptPassword('test123', 'key');
     expect(result, isNotNull);
     expect(result, isNot('test123'));
   });
   ```

2. **Widget测试**: 测试UI组件
   ```dart
   testWidgets('should display password form', (tester) async {
     await tester.pumpWidget(MyApp());
     expect(find.text('添加密码'), findsOneWidget);
   });
   ```

3. **集成测试**: 测试完整功能流程

### 安全考虑

1. **敏感数据**: 不在日志中输出敏感信息
2. **加密存储**: 所有密码数据必须加密存储
3. **输入验证**: 对所有用户输入进行验证
4. **权限最小化**: 申请最少必要权限

## 🌍 国际化

我们欢迎多语言贡献：

1. **翻译文件**: 位于 `lib/l10n/` 目录
2. **添加新语言**: 创建对应的 `.arb` 文件
3. **翻译指南**: 保持术语一致性，符合本地习惯

## 🎉 认可贡献者

我们在以下地方认可贡献者：

- **README.md**: 贡献者列表
- **CHANGELOG.md**: 版本更新说明
- **GitHub**: 贡献者统计
- **应用内**: 关于页面致谢

## 📞 获取帮助

如果您在贡献过程中遇到问题：

1. **查看现有Issues**: 可能已有相同问题的讨论
2. **查看文档**: 检查是否有相关文档说明
3. **创建Discussion**: 在GitHub Discussions中提问
4. **联系维护者**: 通过Issue或邮件联系

## ✅ 贡献检查清单

在提交PR前，请确认：

- [ ] 代码遵循项目规范
- [ ] 添加了必要的测试
- [ ] 测试全部通过
- [ ] 更新了相关文档
- [ ] 提交信息符合规范
- [ ] 没有引入安全风险
- [ ] 功能在多个平台上正常工作
- [ ] 代码经过充分的自测

---

再次感谢您的贡献！您的每一份努力都让这个项目变得更好。🙏 