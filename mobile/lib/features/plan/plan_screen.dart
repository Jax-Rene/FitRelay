import 'package:flutter/material.dart';

import '../../models/exercise_catalog.dart';
import '../../models/workout_plan.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../workout/workout_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late WorkoutPlan _plan;
  bool _adjusting = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  Future<void> _shorten(int minutes) async {
    Navigator.pop(context);
    setState(() => _adjusting = true);
    final adjusted = await ApiClient().shortenPlan(_plan, minutes);
    if (!mounted) return;
    setState(() {
      _plan = adjusted;
      _adjusting = false;
    });
  }

  void _showAdjustments() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '调整今天的计划',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '服务端会保留优先级最高的动作并重新计算时长。',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.sky,
                ),
                title: const Text('浏览动作库'),
                subtitle: const Text('按肌群和器械找到想练的动作'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(this.context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const ExerciseLibraryScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('缩短到 30 分钟'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _shorten(30),
              ),
              ListTile(
                title: const Text('临时只剩 15 分钟'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _shorten(15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strengthExercises = _plan.exercises.where(
      (item) => item.slug != 'incline_treadmill_walk',
    );
    final sets = strengthExercises.fold<int>(0, (sum, item) => sum + item.sets);
    final cardioMinutes =
        _plan.exercises.any((item) => item.slug == 'incline_treadmill_walk')
        ? 15
        : 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日计划'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 120),
                children: [
                  Text(
                    _adjusting ? '正在重新编排' : '恢复型全身训练',
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _plan.title.contains('缩短')
                        ? '时间变了，\n计划跟着变。'
                        : '找回节奏，\n今天不追重量。',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _plan.coachMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Metric('${_plan.estimatedMinutes}', '预计分钟'),
                        _Metric('$sets', '力量组'),
                        _Metric('$cardioMinutes', '有氧分钟'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ..._plan.exercises.indexed.map(
                    (entry) => _ExerciseRow(
                      index: entry.$1,
                      exercise: entry.$2,
                      onReplace: (replacement) =>
                          _replaceExercise(entry.$1, replacement),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _adjusting ? null : _showAdjustments,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_adjusting ? '调整中…' : '调整计划'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _adjusting
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WorkoutScreen(plan: _plan),
                              ),
                            ),
                      child: const Text('开始训练  →'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _replaceExercise(int index, WorkoutExercise replacement) {
    final exercises = [..._plan.exercises];
    exercises[index] = replacement;
    setState(() => _plan = _plan.copyWith(exercises: exercises));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已换成${replacement.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
    ],
  );
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.exercise,
    required this.onReplace,
  });
  final int index;
  final WorkoutExercise exercise;
  final ValueChanged<WorkoutExercise> onReplace;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFF23262D))),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: ColoredBox(
            color: const Color(0xFFE6E8E2),
            child: Image.asset(
              exerciseImageAsset(exercise.slug),
              width: 66,
              height: 66,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 21,
                    height: 21,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF252C1D),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.lime,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                exercise.slug == 'incline_treadmill_walk'
                    ? '15 分钟 · 可以说完整句子的强度'
                    : '${exercise.sets} 组 × ${exercise.repsMin}–${exercise.repsMax} 次 · 休息 ${exercise.restSeconds} 秒',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 5),
              Text(
                exercise.slug == 'incline_treadmill_walk'
                    ? '坡度 5% · 5 km/h'
                    : exercise.loadKg > 0
                    ? '建议 ${exercise.loadKg.toStringAsFixed(0)} kg'
                    : '从轻重量开始探索',
                style: const TextStyle(color: AppColors.lime, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '调整${exercise.name}',
          onPressed: () => _showExerciseMenu(context),
          icon: const Icon(Icons.more_horiz, color: AppColors.muted),
        ),
      ],
    ),
  );

  void _showExerciseMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        exerciseImageAsset(exercise.slug),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '调整动作 ${index + 1}',
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.sky,
                  ),
                  title: const Text('替换动作'),
                  subtitle: const Text('按肌群、器械筛选并查看演示'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLibrary(context, sheetContext),
                ),
                ListTile(
                  leading: const Icon(Icons.tune, color: AppColors.lime),
                  title: const Text('调整重量或组数'),
                  subtitle: const Text('只修改这个动作'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _confirmAction(context, sheetContext, '可在训练中直接调整重量与次数'),
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Color(0xFFFF928C)),
                  title: const Text('从计划中移除'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmAction(context, sheetContext, '已记录移除意图'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLibrary(
    BuildContext pageContext,
    BuildContext sheetContext,
  ) async {
    Navigator.pop(sheetContext);
    final selected = await Navigator.of(pageContext).push<ExerciseCatalogEntry>(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          initialMuscle: muscleForExercise(exercise.slug),
          currentSlug: exercise.slug,
          selectionMode: true,
        ),
      ),
    );
    if (selected != null) onReplace(selected.replace(exercise));
  }

  void _confirmAction(
    BuildContext pageContext,
    BuildContext sheetContext,
    String message,
  ) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
