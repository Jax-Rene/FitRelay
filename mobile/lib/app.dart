import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';

class SuilianApp extends StatefulWidget {
  const SuilianApp({super.key});

  @override
  State<SuilianApp> createState() => _SuilianAppState();
}

class _SuilianAppState extends State<SuilianApp> {
  bool _loggedIn = false;
  bool _onboardingCompleted = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _loggedIn = preferences.getBool('local_session_active') ?? false;
      _onboardingCompleted =
          preferences.getBool('onboarding_completed') ?? false;
      _ready = true;
    });
  }

  Future<void> _login() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('local_session_active', true);
    if (!mounted) return;
    setState(() => _loggedIn = true);
  }

  Future<void> _logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('local_session_active', false);
    if (!mounted) return;
    setState(() => _loggedIn = false);
  }

  Future<void> _completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_completed', true);
    if (!mounted) return;
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '随练 AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !_loggedIn
          ? LoginScreen(onLogin: _login)
          : _onboardingCompleted
          ? HomeScreen(onLogout: _logout)
          : OnboardingScreen(onCompleted: _completeOnboarding),
    );
  }
}
