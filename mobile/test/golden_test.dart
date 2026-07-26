import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suilian_ai/features/auth/login_screen.dart';
import 'package:suilian_ai/features/exercise_library/exercise_library_screen.dart';
import 'package:suilian_ai/features/home/home_screen.dart';
import 'package:suilian_ai/features/onboarding/onboarding_screen.dart';
import 'package:suilian_ai/features/plan/plan_screen.dart';
import 'package:suilian_ai/features/summary/summary_screen.dart';
import 'package:suilian_ai/features/workout/workout_screen.dart';
import 'package:suilian_ai/models/exercise_catalog.dart';
import 'package:suilian_ai/services/api_client.dart';
import 'package:suilian_ai/services/environment_service.dart';
import 'package:suilian_ai/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

ThemeData get goldenTheme => AppTheme.dark.copyWith(
  textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'GoldenChinese'),
  primaryTextTheme: AppTheme.dark.primaryTextTheme.apply(
    fontFamily: 'GoldenChinese',
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      textStyle: const TextStyle(
        fontFamily: 'GoldenChinese',
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      textStyle: const TextStyle(fontFamily: 'GoldenChinese'),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      textStyle: const TextStyle(fontFamily: 'GoldenChinese'),
    ),
  ),
  chipTheme: AppTheme.dark.chipTheme.copyWith(
    labelStyle: AppTheme.dark.chipTheme.labelStyle?.copyWith(
      fontFamily: 'GoldenChinese',
    ),
    secondaryLabelStyle: AppTheme.dark.chipTheme.secondaryLabelStyle?.copyWith(
      fontFamily: 'GoldenChinese',
    ),
  ),
);

Future<void> renderScreen(
  WidgetTester tester,
  Widget screen,
  String goldenName,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: goldenTheme,
      home: RepaintBoundary(key: const Key('capture'), child: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byKey(const Key('capture')),
    matchesGoldenFile('goldens/$goldenName.png'),
  );
}

Future<void> captureCurrent(WidgetTester tester, String goldenName) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await expectLater(
    find.byKey(const Key('capture')),
    matchesGoldenFile('goldens/$goldenName.png'),
  );
}

void main() {
  setUpAll(() async {
    final bytes = await File(
      '/System/Library/Fonts/Hiragino Sans GB.ttc',
    ).readAsBytes();
    final loader = FontLoader('GoldenChinese')
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    final iconBytes = await File(
      '/Users/zhuangjingyang/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(Uint8List.fromList(iconBytes))),
      );
    await iconLoader.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('login screenshot', (tester) async {
    await renderScreen(tester, LoginScreen(onLogin: () async {}), '00_login');
  });

  testWidgets('complete onboarding screenshots', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme,
        home: RepaintBoundary(
          key: const Key('capture'),
          child: OnboardingScreen(onCompleted: () {}),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/branding/logo.png'),
        tester.element(find.byType(OnboardingScreen)),
      );
    });
    await captureCurrent(tester, '01_welcome');
    await tester.tap(find.text('开始设置  →'));
    await captureCurrent(tester, '02_gender');
    for (final name in [
      '03_birthday',
      '04_height',
      '05_weight',
      '06_experience',
      '07_limitations',
      '08_optional_voice',
    ]) {
      await tester.tap(find.text('继续  →'));
      await captureCurrent(tester, name);
    }
    await tester.enterText(find.byType(TextField), '想增肌，偏好器械，不喜欢跑步。');
    await captureCurrent(tester, '09_note_filled');
  });

  testWidgets('home screenshot', (tester) async {
    await renderScreen(
      tester,
      HomeScreen(
        date: DateTime(2026, 7, 13),
        environmentService: _GoldenEnvironmentService(),
      ),
      '10_home',
    );
  });

  testWidgets('plan screenshot', (tester) async {
    await renderScreen(tester, PlanScreen(plan: fallbackPlan(60)), '11_plan');
  });

  testWidgets('workout screenshot', (tester) async {
    await renderScreen(
      tester,
      WorkoutScreen(plan: fallbackPlan(60)),
      '12_workout',
    );
  });

  testWidgets('summary screenshot', (tester) async {
    await renderScreen(
      tester,
      const SummaryScreen(
        completedSets: 9,
        durationSeconds: 2400,
        saveRecord: false,
        completedSetsByExercise: {
          'leg_press': 3,
          'machine_chest_press': 3,
          'lat_pulldown': 3,
        },
      ),
      '13_summary',
    );
  });

  testWidgets('exercise library screenshot', (tester) async {
    await renderScreen(
      tester,
      const ExerciseLibraryScreen(),
      '14_exercise_library',
    );
  });

  testWidgets('exercise detail screenshot', (tester) async {
    await renderScreen(
      tester,
      ExerciseDetailScreen(entry: exerciseCatalog.first, selectionMode: true),
      '15_exercise_detail',
    );
  });

  testWidgets('filtered exercise library screenshot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goldenTheme,
        home: const RepaintBoundary(
          key: Key('capture'),
          child: ExerciseLibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '哑铃'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/16_exercise_library_dumbbell.png'),
    );
  });
}

class _GoldenEnvironmentService implements EnvironmentService {
  @override
  Future<EnvironmentSnapshot?> cached() async => null;

  @override
  Future<EnvironmentSnapshot> refresh() async => EnvironmentSnapshot(
    locationLabel: '上海市 · 徐汇区',
    weatherLabel: '多云 29°',
    humidity: 68,
    updatedAt: DateTime(2026, 7, 13, 12),
  );
}
