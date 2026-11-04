import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_update_service.dart';
import '../theme/internal_ui_theme.dart';

class AppUpdateSection extends StatefulWidget {
  const AppUpdateSection({super.key});
  @override
  State<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends State<AppUpdateSection> {
  late final Future<PackageInfo> _version = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AppUpdateService.instance,
        builder: (context, _) {
          final updates = AppUpdateService.instance;
          return InternalSurface(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.system_update_alt),
                const SizedBox(width: 12),
                Text('版本与更新', style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 14),
              FutureBuilder<PackageInfo>(
                  future: _version,
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Text(info == null
                        ? 'Lockora · 正在读取版本…'
                        : 'Lockora ${info.version}（构建 ${info.buildNumber}）');
                  }),
              const SizedBox(height: 8),
              Text(updates.message,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: updates.isConfigured && !updates.isChecking
                    ? () => updates.checkForUpdates()
                    : null,
                icon: const Icon(Icons.refresh),
                label: Text(updates.isChecking ? '正在检查…' : '检查更新'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('自动检查更新'),
                subtitle: const Text('发现新版本后提示，由你决定何时安装'),
                value: updates.automaticChecks,
                onChanged:
                    updates.isConfigured ? updates.setAutomaticChecks : null,
              ),
            ]),
          );
        },
      );
}
