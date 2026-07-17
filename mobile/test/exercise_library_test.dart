import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suilian_ai/features/exercise_library/exercise_library_screen.dart';
import 'package:suilian_ai/features/plan/plan_screen.dart';
import 'package:suilian_ai/models/exercise_catalog.dart';
import 'package:suilian_ai/services/api_client.dart';
import 'package:suilian_ai/theme/app_theme.dart';

void main() {
  testWidgets(
    'filters chest exercises by equipment and returns a replacement',
    (tester) async {
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
      expect(find.text('找到 12 个动作'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, '哑铃'));
      await tester.pumpAndSettle();
      expect(find.text('找到 3 个动作'), findsOneWidget);
      expect(find.text('哑铃卧推'), findsOneWidget);
      expect(find.text('杠铃卧推'), findsNothing);

      await tester.tap(find.byTooltip('选择 哑铃卧推'));
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
    await tester.tap(find.byTooltip('选择 哑铃卧推'));
    await tester.pumpAndSettle();

    expect(find.text('器械推胸'), findsNothing);
    expect(find.text('哑铃卧推'), findsWidgets);
    expect(find.text('已换成哑铃卧推'), findsOneWidget);
  });
}
