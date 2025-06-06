# 📦 密码管理器构建指南

## 🚀 GitHub Actions 自动构建（推荐）

### 快速开始

1. **将代码推送到GitHub仓库**
2. **启用GitHub Actions**（如果还没启用的话）
3. **选择构建方式**：

#### 方式一：标签触发自动构建 + 发布（推荐）
```bash
# 创建版本标签并推送
git tag v1.0.0
git push origin v1.0.0
```
- ✅ 自动构建Windows和macOS版本
- ✅ 自动创建GitHub Release
- ✅ 自动上传安装包到Release页面

#### 方式二：手动触发构建（测试用）
1. 进入GitHub仓库页面
2. 点击 `Actions` 标签
3. 选择 `手动构建` 工作流
4. 点击 `Run workflow`
5. 选择要构建的平台（Windows/macOS）
6. 点击 `Run workflow` 开始构建

### 📁 构建产物下载

**标签构建**：
- 前往 GitHub 仓库的 `Releases` 页面下载

**手动构建**：
1. 前往 `Actions` 页面
2. 点击对应的构建任务
3. 在 `Artifacts` 部分下载构建产物

## 🖥️ 本地构建（如果你有对应平台）

### macOS 构建
```bash
# 启用桌面支持
flutter config --enable-macos-desktop

# 获取依赖
flutter pub get

# 构建应用
flutter build macos --release

# 创建DMG（需要macOS）
hdiutil create -volname "密码管理器" \
  -srcfolder "build/macos/Build/Products/Release/password_manager.app" \
  -ov -format UDZO "密码管理器-macOS.dmg"
```

### Windows 构建
```bash
# 启用桌面支持
flutter config --enable-windows-desktop

# 获取依赖
flutter pub get

# 构建应用
flutter build windows --release

# 构建产物位于：build/windows/x64/runner/Release/
```

## 📋 构建要求

### GitHub Actions（免费）
- ✅ 无需本地环境
- ✅ 支持Windows和macOS同时构建
- ✅ 自动化发布流程
- ✅ 构建日志清晰

### 本地构建要求
- **Windows构建**: 需要Windows 10/11 + Visual Studio
- **macOS构建**: 需要macOS + Xcode
- **Linux构建**: 需要Linux + 相关开发工具

## 🎯 推荐工作流程

1. **开发阶段**: 使用 `手动构建` 测试
2. **发布阶段**: 使用 `标签构建` 正式发布

### 发布流程示例
```bash
# 1. 完成开发和测试
git add .
git commit -m "feat: 完成所有功能开发"
git push origin main

# 2. 创建版本标签
git tag v1.0.0
git push origin v1.0.0

# 3. GitHub Actions自动构建并发布
# 4. 在Releases页面查看和分享安装包
```

## 🔧 故障排除

### 常见问题

**Q: 构建失败怎么办？**
A: 检查Actions页面的构建日志，通常是依赖问题或代码错误

**Q: 如何修改应用信息？**
A: 编辑以下文件：
- `pubspec.yaml` - 应用名称和版本
- `windows/runner/Runner.rc` - Windows应用信息
- `macos/Runner/Info.plist` - macOS应用信息

**Q: 如何添加应用图标？**
A: 使用 `flutter_launcher_icons` 包自动生成各平台图标

**Q: 构建的应用无法运行？**
A: 确保目标系统满足最低要求：
- Windows 10/11 (x64)
- macOS 10.14+

## 🚀 高级配置

### 自定义构建配置
编辑 `.github/workflows/build-release.yml` 来：
- 修改Flutter版本
- 添加代码签名
- 自定义构建参数
- 添加测试步骤

### 代码签名（可选）
对于生产环境，建议配置代码签名：
- **Windows**: 使用证书签名
- **macOS**: 使用Apple Developer证书

---

## 📞 技术支持

如果遇到构建问题，请：
1. 查看Actions构建日志
2. 检查相关文档
3. 提交Issue到GitHub仓库

**Happy Building! 🎉** 