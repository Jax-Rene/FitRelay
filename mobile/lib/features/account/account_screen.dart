import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('个人中心')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.lime,
                  foregroundColor: Color(0xFF11130D),
                  child: Icon(Icons.person_rounded),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本机训练账户',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '训练数据仅保存在当前设备',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ListTile(
            leading: Icon(Icons.shield_outlined, color: AppColors.lime),
            title: Text('隐私与数据'),
            subtitle: Text('位置仅用于获取本地天气，不会写入训练记录'),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              await onLogout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('退出本机账户'),
          ),
        ],
      ),
    ),
  );
}
