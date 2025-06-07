# 🔐 密码管理器 (Password Manager)

<div align="center">

![密码管理器](https://img.shields.io/badge/Platform-macOS%20|%20Windows%20|%20Linux%20|%20Android-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.22.0-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.3-orange)

**一款安全、离线、开源的本地密码管理工具**

[下载应用](https://github.com/JojoShine/password_manager/releases) • [查看文档](./APP_STORE_GUIDE.md) • [隐私政策](./PRIVACY_POLICY.md) • [报告问题](https://github.com/JojoShine/password_manager/issues)

</div>

## ✨ 功能特性

### 🔒 安全性
- **🔐 本地存储**: 所有数据仅存储在设备本地，永不上传云端
- **🛡️ AES-256加密**: 采用军用级加密算法保护数据
- **🔑 主密码保护**: 使用PBKDF2算法安全哈希主密码
- **👁️ 生物识别**: 支持Touch ID / Face ID快速解锁
- **🔒 自动锁定**: 设定时间后自动锁定应用

### 💡 智能功能
- **🎲 密码生成器**: 支持自定义规则生成强密码
- **📊 安全评估**: 检测弱密码、重复密码和过期密码
- **🔍 快速搜索**: 支持标题、用户名、网站等多字段搜索
- **📂 分类管理**: 内置多种分类，支持自定义分类
- **🏷️ 标签系统**: 灵活的标签管理和筛选

### 🎨 用户体验
- **🌙 深色模式**: 支持明暗主题自动切换
- **📱 响应式设计**: 适配各种屏幕尺寸
- **🎯 现代UI**: 简洁美观的Material Design界面
- **⚡ 快速操作**: 一键复制、批量操作等便捷功能
- **🔄 数据备份**: 支持加密/明文导出和导入

### 🌐 跨平台支持
- **💻 桌面端**: macOS、Windows、Linux
- **📱 移动端**: Android（iOS版本开发中）
- **🌍 多语言**: 支持中文界面

## 📱 App Store 发布

本应用正在准备发布到各大应用商店：

### macOS App Store
- **状态**: 准备中
- **要求**: macOS 10.14+
- **特性**: 完整功能，沙盒安全

### Microsoft Store
- **状态**: 计划中
- **要求**: Windows 10+
- **特性**: 通用Windows平台

### Google Play Store
- **状态**: 计划中
- **要求**: Android 6.0+
- **特性**: 移动端优化

## 🚀 快速开始

### 下载安装

#### 从GitHub Releases下载
1. 访问 [Releases页面](https://github.com/JojoShine/password_manager/releases)
2. 下载适合您系统的版本：
   - **macOS**: `PasswordManager-macOS.dmg`
   - **Windows**: `PasswordManager-Windows.zip`
   - **Linux**: `PasswordManager-Linux.AppImage`
   - **Android**: `PasswordManager-Android.apk`

#### 从源码构建
```bash
# 克隆仓库
git clone https://github.com/JojoShine/password_manager.git
cd password_manager

# 安装依赖
flutter pub get

# 构建应用
flutter build macos --release    # macOS
flutter build windows --release  # Windows
flutter build linux --release    # Linux
flutter build apk --release      # Android
```

### 首次使用
1. **设置主密码**: 创建一个强密码来保护您的数据
2. **启用生物识别**: 可选启用Touch ID/Face ID快速解锁
3. **添加第一个密码**: 点击"添加密码"开始管理您的账户
4. **数据备份**: 建议定期导出数据进行备份

## 📖 使用指南

### 基本操作
- **添加密码**: 点击右上角"+"按钮
- **搜索密码**: 使用顶部搜索框
- **编辑密码**: 双击条目或右键选择编辑
- **复制密码**: 单击密码字段自动复制
- **批量操作**: 长按选择多个条目

### 高级功能
- **密码生成**: 在添加界面使用生成器
- **安全分析**: 在设置中查看安全报告
- **数据导出**: 设置 → 数据管理 → 导出
- **主题切换**: 设置 → 外观 → 主题模式

## 🛡️ 隐私与安全

### 数据安全承诺
- ✅ **零数据收集**: 不收集任何个人信息
- ✅ **本地存储**: 数据永远在您的设备上
- ✅ **开源透明**: 源码公开，接受社区审查
- ✅ **加密保护**: 采用业界标准加密算法
- ✅ **无网络依赖**: 完全离线工作

### 技术实现
- **加密算法**: AES-256-GCM
- **密钥派生**: PBKDF2-SHA256
- **数据完整性**: HMAC验证
- **安全存储**: 平台原生密钥库

详细信息请查看 [隐私政策](./PRIVACY_POLICY.md)

## 🏗️ 技术架构

### 技术栈
- **框架**: Flutter 3.22.0
- **语言**: Dart
- **状态管理**: Provider
- **数据存储**: SharedPreferences + 文件系统
- **加密**: crypto + dart:convert
- **UI**: Material Design 3

### 项目结构
```
lib/
├── models/           # 数据模型
├── services/         # 业务服务
├── pages/            # 页面UI
├── widgets/          # 通用组件
├── utils/            # 工具函数
└── main.dart         # 应用入口
```

### 依赖项
```yaml
dependencies:
  flutter: sdk: flutter
  shared_preferences: ^2.2.3
  crypto: ^3.0.3
  file_picker: ^8.0.0+1
  package_info_plus: ^4.2.0
  local_auth: ^2.2.0
  window_manager: ^0.3.9
```

## 🤝 贡献指南

我们欢迎社区贡献！

### 如何参与
1. **Fork** 这个仓库
2. **创建** 功能分支 (`git checkout -b feature/AmazingFeature`)
3. **提交** 更改 (`git commit -m 'Add some AmazingFeature'`)
4. **推送** 到分支 (`git push origin feature/AmazingFeature`)
5. **创建** Pull Request

### 贡献类型
- 🐛 Bug修复
- ✨ 新功能开发
- 📚 文档改进
- 🌍 多语言翻译
- 🎨 UI/UX改进
- 🔒 安全审查

### 开发环境
```bash
# 安装Flutter
flutter doctor

# 克隆项目
git clone https://github.com/JojoShine/password_manager.git
cd password_manager

# 安装依赖
flutter pub get

# 运行开发版本
flutter run -d macos  # 或其他平台
```

## 📋 开发计划

### v1.1.0 (计划中)
- [ ] iOS版本支持
- [ ] 云同步选项(端到端加密)
- [ ] 更多导入格式支持
- [ ] 密码强度算法改进
- [ ] 多语言支持扩展

### v1.2.0 (规划中)
- [ ] 团队共享功能
- [ ] 审计日志
- [ ] 二次验证支持
- [ ] 浏览器扩展
- [ ] API开放平台

## 📞 支持与反馈

### 获取帮助
- **GitHub Issues**: [报告问题](https://github.com/JojoShine/password_manager/issues)
- **邮箱支持**: [您的邮箱] (替换为实际邮箱)
- **讨论区**: [GitHub Discussions](https://github.com/JojoShine/password_manager/discussions)

### 常见问题
- **忘记主密码**: 由于采用零知识架构，忘记主密码将无法恢复数据，请务必牢记或安全备份
- **数据迁移**: 使用导出/导入功能在设备间迁移数据
- **性能问题**: 大量数据时建议定期清理无用条目

## 📄 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🌟 致谢

感谢以下项目和资源：
- [Flutter团队](https://flutter.dev/) - 优秀的跨平台框架
- [Material Design](https://material.io/) - 设计系统指导
- [Flutter社区](https://flutter.dev/community) - 丰富的生态支持
- 所有贡献者和测试用户

---

<div align="center">

**⭐ 如果这个项目对您有帮助，请考虑给我们一个Star！⭐**

Made with ❤️ by [JojoShine](https://github.com/JojoShine)

</div>
