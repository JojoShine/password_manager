import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/internal_ui_theme.dart';

class Footer extends StatelessWidget {
  const Footer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _openTbtParent(context),
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    color: InternalUiTokens.highlight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Powered by TBTparent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .35,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.open_in_new,
                    size: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            key: const ValueKey('github-project-link'),
            onTap: () => _openGitHub(context),
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Semantics(
                label: 'GitHub 项目',
                button: true,
                child: Image.asset(
                  'assets/github-mark.png',
                  key: const ValueKey('github-project-icon'),
                  width: 17,
                  height: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Theme.of(context).colorScheme.outline,
          ),
          InkWell(
            onTap: () => _showPrivacyPolicy(context),
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '隐私协议',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const PrivacyPolicyDialog();
      },
    );
  }

  Future<void> _openTbtParent(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://tbtparent.me'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开 tbtparent.me')),
      );
    }
  }

  Future<void> _openGitHub(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://github.com/JojoShine/password_manager'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开 GitHub 项目')),
      );
    }
  }
}

class PrivacyPolicyDialog extends StatefulWidget {
  const PrivacyPolicyDialog({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: InternalUiTheme.dialogShape(context, darkRadius: 16),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: InternalUiTheme.dialogRadius(context, darkRadius: 16),
        ),
        child: Column(
          children: [
            // 标题栏
            PixelDialogHeader(
              title: '隐私协议',
              subtitle: '密码库与数据保护说明',
              icon: Icons.privacy_tip,
              onClose: () => Navigator.of(context).pop(),
            ),
            // 隐私协议内容 - 单一区域布局
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? null : InternalUiTokens.surface,
                  border: Border.all(
                    color: isDark
                        ? InternalUiTokens.darkBorder
                        : InternalUiTokens.border,
                    width: 2,
                  ),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      _getPrivacyPolicyContent(),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: isDark
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 底部按钮区域
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? null : InternalUiTokens.weakBackground,
                borderRadius: isDark
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : BorderRadius.zero,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Theme.of(context).dividerColor.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 复制按钮 - 居中放置
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _getPrivacyPolicyContent()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('隐私协议已复制到剪贴板'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制内容'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Theme.of(context).colorScheme.primary
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 我已阅读按钮 - 居中且加宽
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          '我已阅读',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: InternalUiTheme.dialogShape(
                            context,
                            darkRadius: 12,
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPrivacyPolicyContent() {
    return '''Lockora - 隐私政策

最后更新：2026年11月5日
版本：3.1.1

一、数据保管

Lockora 不要求注册账户，开发者不接收主密码或密码库内容。密码库保存在本机；选择 iCloud Drive 等目录后，由对应云盘服务同步文件。

二、桌面密码库加密

3.1.1 起，macOS、Windows 密码库主文件、自动备份和写入临时文件均采用 AES-256-GCM 认证加密。密钥由主密码通过带随机盐的 PBKDF2-HMAC-SHA256（600,000 次）派生，每次写入使用新的随机 nonce。锁定后停止密码库读写。

同一个同步库在各设备使用同一个主密码，遗忘后无法由服务器找回。所有同步设备应先退出旧版并升级，再解锁迁移；旧版不得继续写入新格式。

迁移不会自动清理旧目录、历史导出、系统备份或云盘历史版本。Web 和移动端沿用原有存储，本次桌面加密不代表这些平台获得相同保护。

三、导出与删除

加密 JSON 导出与普通 JSON、CSV 导出不同，后两者是明文。请自行保管备份。清空记录保留由原主密码保护的空加密库；卸载不会自动删除密码库或云盘副本。

四、扩展与网络

扩展通过本机回环连接访问已解锁应用，按用户操作查询、填充或保存凭据。版本检查和下载向发布服务器发送 HTTPS 请求，不携带主密码或密码库内容；服务器可获得 IP、请求时间等常规访问记录。外部链接遵循目标网站的数据规则。

五、联系与源码

GitHub：https://github.com/JojoShine/password_manager
问题反馈：https://github.com/JojoShine/password_manager/issues''';
  }
}
