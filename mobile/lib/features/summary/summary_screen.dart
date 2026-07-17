import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.completedSets,
    required this.durationSeconds,
    this.completedSetsByExercise = const {},
  });

  final int completedSets;
  final int durationSeconds;
  final Map<String, int> completedSetsByExercise;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<Map<String, dynamic>> _summary;

  @override
  void initState() {
    super.initState();
    _saveLocalRecord();
    _summary = ApiClient().createSummary(
      seconds: widget.durationSeconds,
      completedSets: widget.completedSets,
    );
  }

  Future<void> _saveLocalRecord() async {
    if (widget.completedSets <= 0 || widget.durationSeconds <= 0) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('last_completed_sets', widget.completedSets);
    await preferences.setInt('last_duration_seconds', widget.durationSeconds);
    await preferences.setInt(
      'last_completed_at_ms',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _summary,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final hasCompletedWork = widget.completedSets > 0;
            final muscleSets = _muscleSets(widget.completedSetsByExercise);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 18),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2ED8FF3E),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF11130D),
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '今天完成了',
                        style: TextStyle(
                          color: AppColors.lime,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasCompletedWork
                            ? (data?['headline'] as String?) ?? '正在整理训练…'
                            : '今天先到这里，没有虚构完成数据。',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat('${widget.durationSeconds ~/ 60}', '分钟'),
                          _Stat('${widget.completedSets}', '有效组'),
                          _Stat('${muscleSets.length}', '肌群'),
                          _Stat('${widget.completedSets * 28}', '估算千卡'),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20251A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '一个真实记录',
                              style: TextStyle(
                                color: AppColors.lime,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasCompletedWork
                                  ? (data?['factual_message'] as String?) ??
                                        '只统计本次实际完成的数据。'
                                  : '本次没有完成有效组，因此不会写入训练记录。',
                              style: const TextStyle(height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        hasCompletedWork
                            ? '一周没有训练，今天没有追重量是合理的。主要肌群已经重新覆盖，下次可以从今天的状态继续。'
                            : '总结只统计真实完成的动作和组数。',
                        style: TextStyle(color: AppColors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 18),
                      if (muscleSets.isNotEmpty)
                        _BodyCoverage(muscleSets: muscleSets)
                      else if (hasCompletedWork)
                        const Text(
                          '本次缺少动作明细，不生成肌群覆盖估算。',
                          style: TextStyle(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  child: FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    child: const Text('完成，回到首页'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Map<String, int> _muscleSets(Map<String, int> exerciseSets) {
  const muscleByExercise = {
    'leg_press': '腿部',
    'machine_leg_curl': '腿部',
    'machine_chest_press': '胸部',
    'lat_pulldown': '背部',
  };
  final result = <String, int>{};
  for (final entry in exerciseSets.entries) {
    final muscle = muscleByExercise[entry.key];
    if (muscle == null || entry.value <= 0) continue;
    result.update(
      muscle,
      (sets) => sets + entry.value,
      ifAbsent: () => entry.value,
    );
  }
  return result;
}

class _BodyCoverage extends StatelessWidget {
  const _BodyCoverage({required this.muscleSets});

  final Map<String, int> muscleSets;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF171A1F),
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '肌群覆盖',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              '颜色越深，本次刺激越多',
              style: TextStyle(color: AppColors.lime, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _BodyFigure(front: true, muscles: muscleSets.keys.toSet()),
            ),
            Expanded(
              child: _BodyFigure(
                front: false,
                muscles: muscleSets.keys.toSet(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: muscleSets.entries.map((entry) {
                  final percentage = (entry.value * 28).clamp(1, 100);
                  return _CoverageRow(
                    entry.key,
                    '$percentage%',
                    percentage / 100,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({required this.front, required this.muscles});
  final bool front;
  final Set<String> muscles;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 145,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SvgPicture.asset(
              front
                  ? 'assets/muscles/body_front.svg'
                  : 'assets/muscles/body_back.svg',
              colorFilter: const ColorFilter.mode(
                Color(0xFF818892),
                BlendMode.srcIn,
              ),
            ),
            ...(front
                    ? [
                        if (muscles.contains('腿部')) 'front_legs.svg',
                        if (muscles.contains('胸部')) 'front_chest.svg',
                        if (muscles.contains('核心')) 'front_core.svg',
                      ]
                    : [
                        if (muscles.contains('背部')) 'back_back.svg',
                        if (muscles.contains('腿部')) 'back_legs.svg',
                      ])
                .map(
                  (asset) => Opacity(
                    opacity: asset.contains('core')
                        ? .45
                        : asset.contains('chest')
                        ? .72
                        : .95,
                    child: SvgPicture.asset(
                      'assets/muscles/$asset',
                      colorFilter: const ColorFilter.mode(
                        AppColors.lime,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
      Text(
        front ? '正面' : '背面',
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      ),
    ],
  );
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow(this.label, this.value, this.opacity);
  final String label;
  final String value;
  final double opacity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
