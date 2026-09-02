# 密码管理工具

<div align="center">

<img src="assets/app.png" width="112" alt="密码管理工具图标">

**一款像素风格、无需账户、数据保存在本机的桌面密码管理器。**

[macOS 下载](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/PasswordManager-macos.zip) · [Windows 下载](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/PasswordManager-windows.zip) · [问题反馈](https://github.com/JojoShine/password_manager/issues) · [TBTparent](https://tbtparent.me)

![Version](https://img.shields.io/badge/version-3.0.0-26231f)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-2f67c7)
![License](https://img.shields.io/badge/license-MIT-d9aa13)

</div>

## 主要功能

- 使用主密码进入密码库，支持手动锁定和离开后台超时自动锁定。
- 添加、查看、编辑、删除和搜索密码，按社交、邮箱、购物、银行、工作等分类筛选。
- 按长度和字符类型生成随机密码，可直接保存为密码条目。
- 支持 JSON、加密 JSON 和 CSV 的导入、导出与备份。
- 内置 Chromium 浏览器扩展，支持查询、一键填充和登录成功后提示保存密码。
- 可查看密码数据文件所在目录，一键清理本地密码记录。
- Windows 可在设置中更改密码数据存放位置。
- 像素风格浅色与深色界面，窗口尺寸会结合可用屏幕空间进行调整。

## 下载与安装

当前发布版本为 `3.0.0`，提供 macOS 和 Windows 桌面版。

### Windows

1. 下载 [PasswordManager-windows.zip](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/PasswordManager-windows.zip)。
2. 将压缩包放到用于长期存放程序的磁盘或目录中，不要放在临时下载目录。
3. 完整解压后运行目录中的 `.exe` 文件；不要只复制可执行文件，应用需要同目录中的其他运行文件。
4. 如需桌面入口，右键 `.exe`，选择“发送到 → 桌面快捷方式”。

### macOS

1. 下载 [PasswordManager-macos.zip](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/PasswordManager-macos.zip)。
2. 解压后，将密码管理工具拖入本机“应用程序”目录。
3. 从“应用程序”目录启动应用。

## 首次使用

1. 启动应用并设置主密码。主密码不限制长度，但应选择自己能够记住且不易被猜到的内容。
2. 主密码无法由开发者找回，请妥善保管。
3. 点击“添加密码”创建第一条记录，或通过右上角的数据菜单导入已有密码。
4. 建议在录入数据后及时导出一份加密备份，并将备份保存在可靠位置。

## 浏览器扩展

扩展支持 Chrome、Edge 等 Chromium 内核浏览器，并通过本机回环地址与正在运行的密码管理工具通信。

### 安装

1. 进入应用，点击顶部的浏览器扩展按钮并下载扩展压缩包。
2. 建议将压缩包及解压后的扩展目录与应用程序放在一起长期管理，避免误删。
3. 打开浏览器扩展管理页：Chrome 使用 `chrome://extensions/`，Edge 使用 `edge://extensions/`。
4. 开启“开发者模式”，点击“加载已解压的扩展程序”，选择扩展目录。
5. 将扩展固定到浏览器工具栏，方便随时使用。

### 使用

1. 保持密码管理工具运行并完成解锁。
2. 打开登录网站，点击扩展图标查看当前网站匹配的账号并执行填充。
3. 输入新账号密码并提交登录后，扩展会等待登录结果；确认登录成功后才显示保存提示。

如果扩展提示连接失败，请先确认桌面应用正在运行且已解锁，再在扩展中重新连接。重新安装应用时，也应重新从最新版应用内下载扩展。

## 数据存放与备份

密码记录只保存在当前设备，不提供账户注册或云同步。

默认数据目录：

- macOS：`~/Library/Application Support/PasswordManager`
- Windows：`%APPDATA%\PasswordManager`

Windows 用户可在“设置 → 数据与应用”中选择新的存放位置。应用会先复制并校验已有数据；为避免覆盖其他密码库，目标应为空目录。

应用会维护 `passwords.json` 和本地备份文件。桌面数据文件由用户自行保管，主密码用于应用访问控制，并不等同于磁盘加密。建议开启系统磁盘加密，并使用应用的“加密导出”功能保存外部备份。明文 JSON 与 CSV 导出可被直接读取，请勿存放在公开或不可信位置。

“一键重置密码数据”会删除密码记录及其本地备份，但会保留主密码和界面设置。执行前请确认已经完成所需备份。

## 自动锁定

- 应用进入后台后开始计算离开时间，回到前台时检查是否达到锁定时限。
- 默认自动锁定时间为 30 分钟，可在设置中调整。
- 手动锁定或自动锁定都会关闭当前打开的业务弹窗并返回解锁页。
- 连续输错主密码达到限制后，应用会暂时禁止继续尝试。

## 从源码运行

项目的发布构建使用 Flutter `3.41.9`。

```bash
git clone https://github.com/JojoShine/password_manager.git
cd password_manager
flutter pub get

# macOS
flutter run -d macos

# Windows
flutter run -d windows
```

构建发布版本：

```bash
flutter build macos --release
flutter build windows --release
```

macOS 构建需要 Xcode；Windows 构建需要 Visual Studio 的桌面 C++ 工具链。

## 项目结构

```text
lib/
├── models/       数据模型
├── pages/        应用页面
├── services/     存储、认证、导入导出及插件通信
├── utils/        通用工具
├── widgets/      像素风格组件
└── main.dart     应用入口

assets/
└── files/password_manager_browser.zip   应用内置浏览器扩展包
```

浏览器扩展源码位于同级的 `password_manager_browser` 目录。修改扩展后，需要重新生成并替换应用内的扩展压缩包。

## 隐私与安全边界

- 应用不会把密码库上传到开发者服务器。
- 浏览器扩展仅通过 `127.0.0.1` 与本机应用通信。
- 只有在主动下载扩展或点击外部链接时，应用才会访问对应网络地址。
- 忘记主密码后无法通过开发者服务恢复；请依靠自己保存的主密码和备份文件。

详细说明见 [隐私政策](PRIVACY_POLICY.md) 和 [安全政策](SECURITY.md)。

## 参与贡献

欢迎提交 Issue 或 Pull Request。开始开发前请阅读 [贡献指南](CONTRIBUTING.md)。

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

<div align="center">

Powered by [TBTparent](https://tbtparent.me) · [GitHub](https://github.com/JojoShine/password_manager)

</div>
