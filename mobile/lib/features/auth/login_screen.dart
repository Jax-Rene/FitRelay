import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});

  final Future<void> Function() onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _login() async {
    if (_loading) return;
    setState(() => _loading = true);
    await widget.onLogin();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/branding/logo.png', width: 72, height: 72),
            const Spacer(),
            const Text(
              '每次来，\n都知道怎么练。',
              style: TextStyle(
                fontSize: 40,
                height: 1.12,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '一键进入你的本机训练账户。训练记录和身体信息默认只保存在这台设备。',
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 36),
            FilledButton.icon(
              onPressed: _loading ? null : _login,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.phone_android_rounded),
              label: Text(_loading ? '正在进入…' : '本机一键登录'),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.muted,
                ),
                SizedBox(width: 6),
                Text(
                  '无需手机号 · 无需验证码',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
