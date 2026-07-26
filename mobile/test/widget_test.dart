import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suilian_ai/app.dart';
import 'package:suilian_ai/features/home/home_screen.dart';
import 'package:suilian_ai/features/workout/workout_screen.dart';
import 'package:suilian_ai/models/workout_record.dart';
import 'package:suilian_ai/services/api_client.dart';
import 'package:suilian_ai/services/environment_service.dart';
import 'package:suilian_ai/theme/app_theme.dart';

void main() {
  testWidgets('new users sign in with one tap before profile setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SuilianApp());
    await tester.pumpAndSettle();
    expect(find.text('本机一键登录'), findsOneWidget);
    expect(find.text('无需手机号 · 无需验证码'), findsOneWidget);

    await tester.tap(find.text('本机一键登录'));
    await tester.pumpAndSettle();
    expect(find.text('欢迎来到随练 AI'), findsOneWidget);
    expect(find.text('不用坚持打卡，\n每次来都能练。'), findsOneWidget);

    await tester.tap(find.text('开始设置  →'));
    await tester.pumpAndSettle();
    expect(find.text('怎么称呼你的\n身体数据？'), findsOneWidget);
    expect(find.text('1 / 7 · 性别'), findsOneWidget);
  });

  testWidgets('completed workout opens instantly and offers restart', (
    tester,
  ) async {
    final now = DateTime.now();
    final record = WorkoutRecord(
      id: 'today',
      completedAt: now,
      durationSeconds: 2400,
      completedSets: 9,
      completedSetsByExercise: const {
        'leg_press': 3,
        'machine_chest_press': 3,
        'lat_pulldown': 3,
      },
    );
    SharedPreferences.setMockInitialValues({
      'workout_records_v1': [jsonEncode(record.toJson())],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          date: now,
          environmentService: _FakeEnvironmentService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日训练已完成'), findsOneWidget);
    expect(find.text('重新开练'), findsOneWidget);
    expect(find.text('沿用上次'), findsNothing);
    expect(find.text('上海市 · 徐汇区'), findsOneWidget);
    expect(find.text('湿度 68%'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('today_record')));
    await tester.tap(find.byKey(const Key('today_record')));
    await tester.pumpAndSettle();
    expect(find.text('完成 9 个有效组，训练已记录。'), findsOneWidget);
    expect(find.text('正在整理训练…'), findsNothing);
  });

  testWidgets('an older workout is not presented as completed today', (
    tester,
  ) async {
    final today = DateTime(2026, 7, 24);
    final record = WorkoutRecord(
      id: 'yesterday',
      completedAt: DateTime(2026, 7, 23, 20),
      durationSeconds: 1800,
      completedSets: 6,
      completedSetsByExercise: const {'leg_press': 3, 'lat_pulldown': 3},
    );
    SharedPreferences.setMockInitialValues({
      'workout_records_v1': [jsonEncode(record.toJson())],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          date: today,
          environmentService: _FakeEnvironmentService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日训练已完成'), findsNothing);
    expect(find.text('今天怎么练？'), findsOneWidget);
    expect(find.text('重新开练'), findsNothing);
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
          child: HomeScreen(
            date: DateTime(2026, 7, 13),
            environmentService: _FakeEnvironmentService(),
          ),
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

class _FakeEnvironmentService implements EnvironmentService {
  @override
  Future<EnvironmentSnapshot?> cached() async => null;

  @override
  Future<EnvironmentSnapshot> refresh() async => EnvironmentSnapshot(
    locationLabel: '上海市 · 徐汇区',
    weatherLabel: '多云 29°',
    humidity: 68,
    updatedAt: DateTime(2026, 7, 24, 12),
  );
}
