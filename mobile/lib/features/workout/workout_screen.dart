import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/exercise_catalog.dart';
import '../../models/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../summary/summary_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _exerciseIndex = 0;
  int _setIndex = 1;
  int _completedSets = 0;
  final Map<String, int> _completedSetsByExercise = {};
  late List<WorkoutExercise> _exercises;
  late double _load;
  int _reps = 10;
  late int _restSeconds;
  late final DateTime _startedAt;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  bool _finishing = false;
  bool _allowPop = false;

  WorkoutExercise get _exercise => _exercises[_exerciseIndex];

  @override
  void initState() {
    super.initState();
    _exercises = [...widget.plan.exercises];
    _load = _exercises.first.loadKg;
    _restSeconds = _exercises.first.restSeconds;
    _startedAt = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      });
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _completeSet() {
    HapticFeedback.mediumImpact();
    setState(() {
      _completedSets++;
      _completedSetsByExercise.update(
        _exercise.slug,
        (sets) => sets + 1,
        ifAbsent: () => 1,
      );
    });
    if (_setIndex < _exercise.sets) {
      setState(() => _setIndex++);
      _showRest();
    } else if (_exerciseIndex < _exercises.length - 1) {
      setState(() {
        _exerciseIndex++;
        _setIndex = 1;
        _load = _exercise.loadKg;
        _reps = _exercise.repsMin;
        _restSeconds = _exercise.restSeconds;
      });
    } else {
      _finish();
    }
  }

  void _showRest() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panelSoft,
      builder: (context) => _RestCountdownSheet(seconds: _restSeconds),
    );
  }

  void _finish() {
    if (_completedSets == 0 || _finishing) return;
    _finishing = true;
    _elapsedTimer?.cancel();
    final durationSeconds = DateTime.now()
        .difference(_startedAt)
        .inSeconds
        .clamp(1, 24 * 60 * 60);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SummaryScreen(
          completedSets: _completedSets,
          durationSeconds: durationSeconds,
          completedSetsByExercise: Map.unmodifiable(_completedSetsByExercise),
        ),
      ),
    );
  }

  Future<void> _requestFinish() async {
    if (_completedSets > 0) {
      _finish();
      return;
    }
    final abandon = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('还没有完成任何一组'),
        content: const Text('现在结束不会保存训练记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续训练'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃训练'),
          ),
        ],
      ),
    );
    if (abandon == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestFinish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('训练中 · ${_formatElapsed(_elapsedSeconds)}'),
          actions: [
            TextButton(onPressed: _requestFinish, child: const Text('结束')),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            children: [
              LinearProgressIndicator(
                value:
                    (_exerciseIndex + (_setIndex / _exercise.sets)) /
                    _exercises.length,
                minHeight: 3,
                backgroundColor: AppColors.line,
                color: AppColors.lime,
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '动作 ${_exerciseIndex + 1} / ${_exercises.length}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  TextButton(
                    onPressed: _showExerciseList,
                    child: const Text('全部动作 ≡'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey(_exercise.slug),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'workout-${_exercise.slug}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: const Color(0xFFE7E8E3),
                            child: Image.asset(
                              exerciseImageAsset(_exercise.slug),
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _exercise.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _exercise.cue,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                children: List.generate(_exercise.sets, (index) {
                  final number = index + 1;
                  final done = number < _setIndex;
                  return CircleAvatar(
                    backgroundColor: number == _setIndex
                        ? AppColors.lime
                        : done
                        ? const Color(0xFF25321C)
                        : AppColors.panelSoft,
                    foregroundColor: number == _setIndex
                        ? const Color(0xFF11130D)
                        : done
                        ? AppColors.lime
                        : AppColors.muted,
                    child: Text(done ? '✓' : '$number'),
                  );
                }),
              ),
              const SizedBox(height: 18),
              Text(
                '第 $_setIndex 组，共 ${_exercise.sets} 组',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              _RestControl(
                seconds: _restSeconds,
                onMinus: () => setState(
                  () => _restSeconds = (_restSeconds - 15).clamp(15, 300),
                ),
                onPlus: () => setState(
                  () => _restSeconds = (_restSeconds + 15).clamp(15, 300),
                ),
              ),
              const SizedBox(height: 10),
              _Control(
                label: '重量',
                value: _load.toStringAsFixed(0),
                unit: 'kg',
                onMinus: () =>
                    setState(() => _load = (_load - 5).clamp(0, 500)),
                onPlus: () => setState(() => _load += 5),
              ),
              const SizedBox(height: 10),
              _Control(
                label: '次数',
                value: '$_reps',
                unit: '次',
                onMinus: () =>
                    setState(() => _reps = (_reps - 1).clamp(0, 100)),
                onPlus: () => setState(() => _reps++),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _completeSet,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('完成本组'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _showExerciseActions,
                icon: const Icon(Icons.tune_rounded, size: 19),
                label: const Text('调整本动作'),
              ),
              const SizedBox(height: 76),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCoach,
          backgroundColor: AppColors.lime,
          foregroundColor: const Color(0xFF11130D),
          child: const Icon(Icons.graphic_eq_rounded),
        ),
      ),
    );
  }

  void _showExerciseActions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '调整本动作',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _exercise.name,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.sky,
                ),
                title: const Text('替换动作'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _replaceCurrentExercise();
                },
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.lime,
                ),
                title: const Text('减少一组'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reduceSet();
                },
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(
                  Icons.skip_next_rounded,
                  color: AppColors.orange,
                ),
                title: const Text('结束动作'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _endExercise();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reduceSet() {
    if (_setIndex < _exercise.sets) {
      setState(() => _setIndex++);
    }
  }

  void _endExercise() {
    if (_exerciseIndex < _exercises.length - 1) {
      setState(() {
        _exerciseIndex++;
        _setIndex = 1;
        _load = _exercise.loadKg;
        _reps = _exercise.repsMin;
        _restSeconds = _exercise.restSeconds;
      });
    } else {
      _requestFinish();
    }
  }

  Future<void> _replaceCurrentExercise() async {
    final current = _exercise;
    final selected = await Navigator.of(context).push<ExerciseCatalogEntry>(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          initialMuscle: muscleForExercise(current.slug),
          currentSlug: current.slug,
          selectionMode: true,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final replacement = selected.replace(current);
    setState(() {
      _exercises[_exerciseIndex] = replacement;
      _setIndex = 1;
      _load = replacement.loadKg;
      _reps = replacement.repsMin;
      _restSeconds = replacement.restSeconds;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('当前动作已换成${replacement.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCoach() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq_rounded, color: AppColors.lime, size: 44),
              SizedBox(height: 12),
              Text(
                '问随练 AI',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                '可以随时询问动作问题，或用语音调整当前训练。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '全部动作',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ..._exercises.indexed.map(
              (entry) => ListTile(
                selected: entry.$1 == _exerciseIndex,
                leading: CircleAvatar(child: Text('${entry.$1 + 1}')),
                title: Text(entry.$2.name),
                subtitle: Text(
                  '${entry.$2.sets} 组 · ${entry.$2.loadKg.toStringAsFixed(0)} kg',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _exerciseIndex = entry.$1;
                    _setIndex = 1;
                    _load = entry.$2.loadKg;
                    _reps = entry.$2.repsMin;
                    _restSeconds = entry.$2.restSeconds;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatElapsed(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

class _RestControl extends StatelessWidget {
  const _RestControl({
    required this.seconds,
    required this.onMinus,
    required this.onPlus,
  });

  final int seconds;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.panel,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text('组间休息', style: TextStyle(color: AppColors.muted)),
        ),
        IconButton(
          onPressed: onMinus,
          tooltip: '减少休息 15 秒',
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 54,
          child: Text(
            '$seconds 秒',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: onPlus,
          tooltip: '增加休息 15 秒',
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    ),
  );
}

class _RestCountdownSheet extends StatefulWidget {
  const _RestCountdownSheet({required this.seconds});

  final int seconds;

  @override
  State<_RestCountdownSheet> createState() => _RestCountdownSheetState();
}

class _RestCountdownSheetState extends State<_RestCountdownSheet> {
  static const _soundChannel = MethodChannel(
    'ai.suilian.suilian_ai/rest_timer',
  );

  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_remainingSeconds <= 1) {
      _timer?.cancel();
      setState(() => _remainingSeconds = 0);
      unawaited(_playCompletionSound());
      return;
    }
    setState(() => _remainingSeconds--);
  }

  Future<void> _playCompletionSound() async {
    try {
      await _soundChannel.invokeMethod<void>('playCompletionSound');
    } on MissingPluginException {
      await SystemSound.play(SystemSoundType.click);
    } on PlatformException {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _remainingSeconds == 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              finished ? '休息完成' : '休息中',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              '$_remainingSeconds 秒',
              style: const TextStyle(
                color: AppColors.lime,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              finished ? '提示音已响，可以开始下一组' : '倒计时结束后会响铃提醒',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(finished ? '继续训练' : '跳过休息'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.value,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
  });
  final String label;
  final String value;
  final String unit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 6),
      Container(
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onMinus,
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(
                minimumSize: const Size(62, 62),
                backgroundColor: AppColors.panelSoft,
              ),
            ),
            Expanded(
              child: Text(
                '$value  $unit',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: onPlus,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                minimumSize: const Size(62, 62),
                backgroundColor: AppColors.panelSoft,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
