import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';

class SuilianApp extends StatefulWidget {
  const SuilianApp({super.key});

  @override
  State<SuilianApp> createState() => _SuilianAppState();
}

class _SuilianAppState extends State<SuilianApp> {
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
      _onboardingCompleted =
          preferences.getBool('onboarding_completed') ?? false;
      _ready = true;
    });
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
          : _onboardingCompleted
          ? const HomeScreen()
          : OnboardingScreen(onCompleted: _completeOnboarding),
    );
  }
}
