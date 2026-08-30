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
              subtitle: '数据仅在本地加密保存',
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
    return '''密码管理器 - 隐私政策

最后更新：2026年8月30日
版本：3.0.0

一、基本说明

密码管理器不要求注册账户，也不接入广告、行为分析或云同步服务。应用不会主动向开发者服务器上传您的密码、身份信息、使用记录或设备标识。

二、本地数据

您添加的密码记录、分类、应用设置以及自定义图片由应用保存在当前设备。桌面端可在“设置 - 数据与应用”中查看实际存放位置。

主密码不会以明文保存。请自行妥善保管主密码和数据备份；遗忘主密码可能导致数据无法正常使用。

三、浏览器插件通信

浏览器插件通过本机回环地址与密码管理器通信，用于查询、填充或保存凭据。该通信仅发生在当前设备，不会因此把密码上传到云端。

四、导入、导出与删除

- 导入和导出仅访问您主动选择的文件。
- 导出文件由您自行保存和管理，请注意其存放位置及保护方式。
- 您可以删除单条记录，或在“设置 - 数据与应用”中一键清理全部密码记录。
- 卸载应用不一定会自动删除系统数据目录；如需彻底清理，请先使用应用内重置功能或按卸载说明处理。

五、外部链接

只有在您主动点击 TBTparent 或 GitHub 链接时，应用才会交由系统浏览器打开对应网站。访问后的数据处理遵循相应网站的隐私规则。

六、政策更新与联系

隐私政策发生变化时，我们会更新本页的日期和版本。您可以通过以下地址查看源代码、反馈问题或联系我们：

GitHub：https://github.com/JojoShine/password_manager
问题反馈：https://github.com/JojoShine/password_manager/issues''';
  }
}
