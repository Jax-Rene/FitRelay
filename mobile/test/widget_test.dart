import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suilian_ai/app.dart';
import 'package:suilian_ai/features/home/home_screen.dart';
import 'package:suilian_ai/features/workout/workout_screen.dart';
import 'package:suilian_ai/services/api_client.dart';
import 'package:suilian_ai/theme/app_theme.dart';

void main() {
  testWidgets('new users start in onboarding and can enter profile setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SuilianApp());
    await tester.pumpAndSettle();
    expect(find.text('欢迎来到随练 AI'), findsOneWidget);
    expect(find.text('不用坚持打卡，\n每次来都能练。'), findsOneWidget);

    await tester.tap(find.text('开始设置  →'));
    await tester.pumpAndSettle();
    expect(find.text('怎么称呼你的\n身体数据？'), findsOneWidget);
    expect(find.text('1 / 7 · 性别'), findsOneWidget);
  });

  testWidgets('ending before the first set requires explicit abandonment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      MaterialApp(home: WorkoutScreen(plan: fallbackPlan(60))),
    );
    await tester.tap(find.text('结束'));
    await tester.pumpAndSettle();
    expect(find.text('还没有完成任何一组'), findsOneWidget);
    expect(find.text('现在结束不会保存训练记录。'), findsOneWidget);
  });

  testWidgets('rest countdown decreases every second and sounds once at zero', (
    tester,
  ) async {
    const channel = MethodChannel('ai.suilian.suilian_ai/rest_timer');
    var soundCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'playCompletionSound') soundCalls++;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      MaterialApp(home: WorkoutScreen(plan: fallbackPlan(60))),
    );
    await tester.tap(find.text('完成本组'));
    await tester.pump();
    expect(find.text('90 秒'), findsWidgets);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('89 秒'), findsOneWidget);

    await tester.pump(const Duration(seconds: 89));
    expect(find.text('0 秒'), findsOneWidget);
    expect(find.text('休息完成'), findsOneWidget);
    expect(find.text('提示音已响，可以开始下一组'), findsOneWidget);
    expect(soundCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(soundCalls, 1);
  });

  testWidgets('core screens fit a small phone with larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const media = MediaQueryData(
      size: Size(375, 667),
      textScaler: TextScaler.linear(1.2),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: media,
          child: HomeScreen(date: DateTime(2026, 7, 13)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: media,
          child: WorkoutScreen(plan: fallbackPlan(60)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
