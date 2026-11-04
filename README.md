# Lockora

<div align="center">

<img src="assets/app.png" width="112" alt="Lockora 图标">

**一款像素风格、无需账户、数据保存在本机的桌面密码管理器。**

[macOS 下载](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/lockora/releases/3.1.1/Lockora-3.1.1-macos.zip) · [Windows 下载](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/lockora/releases/3.1.1/Lockora-3.1.1-windows-setup.exe) · [问题反馈](https://github.com/JojoShine/password_manager/issues) · [TBTparent](https://tbtparent.me)

![Version](https://img.shields.io/badge/version-3.1.1-26231f)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-2f67c7)
![License](https://img.shields.io/badge/license-MIT-d9aa13)

</div>

## 主要功能

- 桌面密码库默认使用 AES-256-GCM 加密；同一个密码库在各设备使用同一个主密码解锁，支持手动锁定和离开后台超时自动锁定。
- 添加、查看、编辑、删除和搜索密码，按社交、邮箱、购物、银行、工作等分类筛选。
- 按长度和字符类型生成随机密码，可直接保存为密码条目。
- 支持 JSON、加密 JSON 和 CSV 的导入、导出与备份。
- 内置 Chromium 浏览器扩展，支持查询、一键填充和登录成功后提示保存密码。
- 可查看密码数据文件所在目录，一键清理本地密码记录。
- 桌面端可在设置中迁移密码库或接入已有密码库，支持选择 iCloud Drive 等同步目录。
- 像素风格浅色与深色界面，窗口尺寸会结合可用屏幕空间进行调整。

## 下载与安装

当前发布版本为 `3.1.1`，提供 macOS 和 Windows 桌面版。

### Windows

1. 下载 [Lockora-3.1.1-windows-setup.exe](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/lockora/releases/3.1.1/Lockora-3.1.1-windows-setup.exe)。
2. 退出旧版应用，运行安装程序，按提示完成当前用户安装。
3. 从开始菜单或桌面快捷方式启动 Lockora。安装和卸载不会删除密码库。

### macOS

1. 下载 [Lockora-3.1.1-macos.zip](https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/lockora/releases/3.1.1/Lockora-3.1.1-macos.zip)。
2. 退出旧版应用，解压后将 `Lockora.app` 拖入本机“应用程序”目录。
3. 从“应用程序”目录启动 Lockora，确认密码库和设置正常后，再移除旧 `PasswordManager.app`。

3.0.0 用户需手动安装一次 Lockora。首次启动会保留旧设置与密码库路径；设置迁移失败时停止启动并提供重试。从 3.1.0 起，可在“设置 → 版本与更新”中检查后续升级。

## 首次使用

1. 启动应用并设置主密码。主密码不限制长度，但应选择自己能够记住且不易被猜到的内容。
2. 主密码无法由开发者找回，请妥善保管。
3. 点击“添加密码”创建第一条记录，或通过右上角的数据菜单导入已有密码。
4. 建议在录入数据后及时导出一份加密备份，并将备份保存在可靠位置。

## 浏览器扩展

扩展支持 Chrome、Edge 等 Chromium 内核浏览器，并通过本机回环地址与正在运行的密码管理工具通信。

### 安装

1. 进入应用的“浏览器扩展”页面，点击“一键准备扩展”；应用会把配套扩展解压到固定的版本目录，无需联网下载。
2. 选择“打开 Chrome 扩展页”或“打开 Edge 扩展页”，复制页面显示的扩展目录。也可使用“立即下载”手动保存压缩包。
3. 打开浏览器扩展管理页：Chrome 使用 `chrome://extensions/`，Edge 使用 `edge://extensions/`。
4. 开启“开发者模式”，点击“加载已解压的扩展程序”，选择扩展目录。
5. 将扩展固定到浏览器工具栏，方便随时使用。更新后加载新版本目录，并移除旧版扩展。

浏览器要求用户确认安装，普通桌面应用无法静默安装本地扩展。

### 使用

1. 保持密码管理工具运行并完成解锁。
2. 打开登录网站，点击扩展图标查看当前网站匹配的账号并执行填充。
3. 输入新账号密码并提交登录后，扩展会等待登录结果；确认登录成功后才显示保存提示。

如果扩展提示连接失败，请先确认桌面应用正在运行且已解锁，再在扩展中重新连接。重新安装应用时，也应重新从最新版应用内下载扩展。

## 数据存放与备份

应用不提供账户注册或自建云同步服务。默认将密码记录保存在当前设备；选择 iCloud Drive 等云盘目录后，由系统云盘服务同步文件。

默认数据目录：

- macOS：`~/Library/Application Support/PasswordManager`
- Windows：`%APPDATA%\PasswordManager`

桌面用户可在“设置 → 数据与应用 → 更改密码存储位置”中选择新的存放位置，包括 iCloud Drive。应用会创建 `PasswordManager` 子目录，复制并校验已有数据，保留原密码库；目标中存在不同数据时拒绝覆盖。

第二台设备等待文件下载完成后，选择“使用已有密码库”，选中包含 `passwords.json` 的 `PasswordManager` 目录。此操作切换当前密码库，不合并或覆盖两边的数据。加密密码库在所有设备上使用同一个主密码，界面设置仍由各设备独立管理。

应用回到前台时和每隔 5 秒检查文件变化；编辑或删除时以操作开始时的数据版本检查冲突，发现已同步的新数据会拒绝覆盖并提示重新加载。云盘同步有延迟，这不等同于多设备实时协作或自动合并，请避免多台设备同时编辑；云盘产生的冲突副本需自行处理。

从 3.1.1 起，桌面密码库的主文件、自动备份和写入临时文件均采用 AES-256-GCM 加密。密钥由主密码通过带随机盐的 PBKDF2-HMAC-SHA256（600,000 次）派生，解锁时在后台计算；每次写入使用新的随机 nonce。锁定后不允许继续读写密码库。

升级前请先让所有同步设备退出旧版并安装 3.1.1，再在首台设备用原主密码成功解锁并迁移。旧版不能读取新格式，不能再写入同一个同步目录。迁移会校验当前库，错误密码或损坏的主文件不会被自动用备份覆盖。

迁移只保护当前目录中的活动文件，不会自动清理旧目录副本、历史导出或云盘历史版本。外部备份仍可选择“加密 JSON”；普通 JSON 与 CSV 导出是明文，需自行保管。加密保护不等同于整个磁盘加密。

“一键重置密码数据”会清空密码记录与备份内容，保留一个可由原主密码解锁的空加密库及界面设置。执行前请确认已经完成所需备份。

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

## 产品介绍页

[Lockora 官网](https://tbtparent.me/lockora/) 使用根目录的 `landing.html`、`landing.css`、`landing.js` 和 `landing-assets/`；部署说明见 [deploy/README.md](deploy/README.md)。`web/` 是 Flutter 浏览器应用入口，其源文件不能直接双击运行，本次桌面密码库加密也不覆盖 Web 的浏览器本地存储。

## 隐私与安全边界

- 应用不会把密码库上传到开发者服务器。
- 浏览器扩展仅通过 `127.0.0.1` 与本机应用通信。
- 检查和下载更新会访问配置的 HTTPS 发布服务器；扩展准备、外部链接等功能也可能访问对应网络地址。这些请求不携带主密码或密码库内容。
- 忘记主密码后无法通过开发者服务恢复；请依靠自己保存的主密码和备份文件。

详细说明见 [隐私政策](PRIVACY_POLICY.md) 和 [安全政策](SECURITY.md)。

## 参与贡献

欢迎提交 Issue 或 Pull Request。开始开发前请阅读 [贡献指南](CONTRIBUTING.md)。

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

<div align="center">

Powered by [TBTparent](https://tbtparent.me) · [GitHub](https://github.com/JojoShine/password_manager)

</div>
