import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suilian_ai/features/exercise_library/exercise_library_screen.dart';
import 'package:suilian_ai/features/plan/plan_screen.dart';
import 'package:suilian_ai/models/exercise_catalog.dart';
import 'package:suilian_ai/services/api_client.dart';
import 'package:suilian_ai/theme/app_theme.dart';

void main() {
  test('imports the complete exercise catalog with unique local media', () {
    expect(exerciseCatalog, hasLength(873));
    expect(
      exerciseCatalog.map((entry) => entry.sourceId).toSet(),
      hasLength(873),
    );
    expect(exerciseCatalog.every((entry) => entry.images.length == 2), isTrue);
    expect(
      exerciseCatalog.map((entry) => entry.muscle).toSet(),
      containsAll(<String>['胸部', '背部', '腿部', '肩部', '二头', '三头', '核心', '有氧']),
    );
    expect(
      exerciseCatalog.map((entry) => entry.category).toSet(),
      containsAll(ExerciseCategory.values),
    );
  });

  testWidgets('bundles every cover and demonstration image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const SizedBox.shrink()),
    );

    final failures = <String>[];
    await tester.runAsync(() async {
      for (final entry in exerciseCatalog) {
        for (final image in entry.images) {
          try {
            final bytes = await rootBundle.load(image);
            if (bytes.lengthInBytes < 1024) failures.add('$image 内容为空');
          } on Object catch (error) {
            failures.add('$image: $error');
          }
        }
      }
    });

    expect(failures, isEmpty, reason: failures.take(10).join('\n'));
  });

  testWidgets('shows an explicit fallback when an image cannot load', (
    tester,
  ) async {
    final missingImageEntry = ExerciseCatalogEntry(
      slug: 'missing_image_test',
      sourceId: 'missing_image_test',
      name: '缺图测试动作',
      muscle: '全身',
      equipment: ExerciseEquipment.bodyweight,
      level: '测试',
      images: const [
        'assets/exercise_library/not-found-0.jpg',
        'assets/exercise_library/not-found-1.jpg',
      ],
      instructions: const ['测试'],
      cue: '测试',
      defaultLoadKg: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: AnimatedExercisePreview(entry: missingImageEntry)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('示范图暂不可用'), findsOneWidget);
  });

  testWidgets('preloads frames and advances the demonstration smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AnimatedExercisePreview(entry: exerciseCatalog.first),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('起始姿势'), findsOneWidget);
    expect(find.byTooltip('暂停播放'), findsOneWidget);

    for (var step = 0; step < 30; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('结束姿势').evaluate().isNotEmpty) break;
    }
    expect(find.text('结束姿势'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停播放'));
    await tester.pump();
    expect(find.byTooltip('继续播放'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('结束姿势'), findsOneWidget);
  });

  testWidgets('respects reduced motion and offers manual frame advance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: AnimatedExercisePreview(entry: exerciseCatalog.first),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('起始姿势'), findsOneWidget);
    await tester.tap(find.byTooltip('显示结束姿势'));
    await tester.pump();
    expect(find.text('结束姿势'), findsOneWidget);
  });

  testWidgets('opens the full catalog and filters a non-chest muscle', (
    tester,
  ) async {
    final legCount = exerciseCatalog
        .where((entry) => entry.muscle == '腿部')
        .length;
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const ExerciseLibraryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('找到 873 个动作'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '腿部'));
    await tester.pumpAndSettle();
    expect(legCount, greaterThan(100));
    expect(find.text('找到 $legCount 个动作'), findsOneWidget);
  });

  testWidgets(
    'filters chest exercises by equipment and returns a replacement',
    (tester) async {
      final chestStrengthCount = exerciseCatalog
          .where(
            (entry) =>
                entry.muscle == '胸部' &&
                entry.category == ExerciseCategory.strength,
          )
          .length;
      final dumbbellChestStrengthCount = exerciseCatalog
          .where(
            (entry) =>
                entry.muscle == '胸部' &&
                entry.category == ExerciseCategory.strength &&
                entry.equipment == ExerciseEquipment.dumbbell,
          )
          .length;
      ExerciseCatalogEntry? selection;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    selection = await Navigator.of(context)
                        .push<ExerciseCatalogEntry>(
                          MaterialPageRoute(
                            builder: (_) => const ExerciseLibraryScreen(
                              initialMuscle: '胸部',
                              selectionMode: true,
                            ),
                          ),
                        );
                  },
                  child: const Text('打开动作库'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开动作库'));
      await tester.pumpAndSettle();
      expect(chestStrengthCount, greaterThan(12));
      expect(find.text('找到 $chestStrengthCount 个动作'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, '哑铃'));
      await tester.pumpAndSettle();
      expect(find.text('找到 $dumbbellChestStrengthCount 个动作'), findsOneWidget);
      expect(find.text('哑铃卧推'), findsOneWidget);
      expect(find.text('杠铃卧推'), findsNothing);

      final selectDumbbellBenchPress = find.byTooltip('选择 哑铃卧推');
      await tester.ensureVisible(selectDumbbellBenchPress);
      await tester.pumpAndSettle();
      await tester.tap(selectDumbbellBenchPress);
      await tester.pumpAndSettle();
      expect(selection?.slug, 'dumbbell_bench_press');
    },
  );

  testWidgets('replaces a plan exercise with the selected catalog entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PlanScreen(plan: fallbackPlan(60)),
      ),
    );

    await tester.tap(find.byTooltip('调整器械推胸'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '哑铃'));
    await tester.pumpAndSettle();
    final selectDumbbellBenchPress = find.byTooltip('选择 哑铃卧推');
    await tester.ensureVisible(selectDumbbellBenchPress);
    await tester.pumpAndSettle();
    await tester.tap(selectDumbbellBenchPress);
    await tester.pumpAndSettle();

    expect(find.text('器械推胸'), findsNothing);
    expect(find.text('哑铃卧推'), findsWidgets);
    expect(find.text('已换成哑铃卧推'), findsOneWidget);
  });
}
