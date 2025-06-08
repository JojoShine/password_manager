import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Footer extends StatelessWidget {
  const Footer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 技术支持信息
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    'assets/app.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.support_agent,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '技术支持：甜宝塔家长',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 隐私协议
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showPrivacyPolicy(context),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text(
                    '隐私协议',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDark ? null : Colors.white, // 浅色模式下强制使用白色背景
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? null : Colors.white, // 浅色模式下强制使用白色背景
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? null : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Theme.of(context).dividerColor.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '隐私协议',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.black87,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.black54,
                    ),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            // 隐私协议内容 - 单一区域布局
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? null : Colors.white,
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
                color: isDark ? null : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
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

生效日期: 2025年1月15日

概述

我们深知隐私的重要性，致力于保护您的个人信息。本隐私政策说明了密码管理器应用如何处理您的数据。

简言之: 我们不收集、存储或传输任何您的个人数据。所有数据都安全地存储在您的设备上。

数据收集

我们不收集的数据:
❌ 个人身份信息
❌ 密码或敏感数据
❌ 使用统计信息
❌ 崩溃报告
❌ 分析数据
❌ 广告标识符
❌ 位置信息
❌ 联系人信息

我们收集的数据:
✅ 无 - 我们不收集任何数据

数据存储

本地存储:
• 所有密码和相关数据仅存储在您的设备上
• 使用AES-256加密算法保护数据
• 数据存储在应用的沙盒环境中，其他应用无法访问
• 您的主密码永远不会以明文形式存储

云服务:
• 本应用不使用任何云服务
• 不与iCloud、Google Drive或其他云存储服务同步
• 所有数据处理都在本地完成

数据使用

应用功能:
您的数据仅用于以下目的：
• 在应用内显示和管理您的密码
• 执行搜索和筛选操作
• 生成密码安全报告
• 数据导入和导出功能

数据访问:
• 只有您可以访问自己的数据
• 应用开发者无法访问您的数据
• 没有后门或远程访问功能

数据安全

加密保护:
• 主密码使用PBKDF2算法进行哈希处理
• 密码数据使用AES-256-GCM加密
• 每个密码条目都有独立的加密参数
• 支持硬件安全模块（如果设备支持）

身份验证:
• 应用锁定机制
• 自动锁定功能

数据完整性:
• 使用HMAC验证数据完整性
• 定期检查数据一致性
• 防止数据篡改

数据导出和删除

数据导出:
• 您可以随时导出所有数据
• 支持加密和明文导出格式
• 导出文件完全由您控制

数据删除:
• 卸载应用将永久删除所有本地数据
• 可以在应用内手动删除特定数据
• 提供安全擦除功能

第三方服务

我们不使用:
• 广告网络
• 数据分析服务
• 云存储服务
• 社交网络集成
• 支付处理服务（应用免费）

操作系统服务:
应用仅使用以下系统服务：
• 文件系统访问（用于导入/导出）
• 生物识别服务（用于身份验证）
• 本地存储服务

儿童隐私

本应用不专门面向13岁以下儿童设计，但由于我们不收集任何数据，因此适合所有年龄段使用。

权限说明

文件系统访问:
• 用途: 允许您选择文件位置进行数据导入和导出
• 范围: 仅限于您明确选择的文件和文件夹
• 控制: 每次访问都需要您的明确授权

生物识别:
• 用途: 提供便捷的应用解锁方式
• 存储: 生物识别数据由系统管理，应用无法访问
• 可选: 您可以选择不使用此功能

数据传输

❌ 不向任何服务器传输数据
❌ 不与其他应用共享数据
❌ 不通过网络发送任何信息
✅ 完全离线工作

隐私政策更新

如果我们更新此隐私政策：
• 会在应用内通知您
• 新版本会标明更新日期
• 重大更改需要您的明确同意

开源透明

本应用是开源的，您可以：
• 查看完整源代码
• 验证隐私声明的真实性
• 参与代码审查
• 提出安全建议

GitHub地址: https://github.com/JojoShine/password_manager

联系我们

如果您对此隐私政策有任何疑问或担忧，请通过以下方式联系我们：

• GitHub Issues: https://github.com/JojoShine/password_manager/issues

法律依据

我们处理您数据的法律依据是：
• 合法利益: 提供密码管理功能
• 用户同意: 您选择使用我们的应用
• 合同履行: 提供您所请求的服务

数据保护权利

根据适用的数据保护法律，您有权：
• 知情权：了解我们如何使用您的数据
• 访问权：获取我们持有的您的数据副本
• 更正权：更正不准确的数据
• 删除权：要求删除您的数据
• 限制处理权：限制我们处理您的数据
• 数据可携权：以结构化格式获取您的数据

注意: 由于我们不收集或存储您的数据，上述大部分权利通过应用的本地功能自动实现。

最后更新: 2025年1月15日
版本: 1.0.0

本隐私政策遵循GDPR、CCPA和其他适用的数据保护法律。''';
  }
}
