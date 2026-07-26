import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/workout_record.dart';
import '../../services/environment_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../account/account_screen.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../history/history_screen.dart';
import '../plan/plan_screen.dart';
import '../summary/summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.date,
    this.onLogout,
    this.environmentService,
    this.apiClient,
  });

  final DateTime? date;
  final Future<void> Function()? onLogout;
  final EnvironmentService? environmentService;
  final ApiClient? apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController(
    text: '一周没练，今天有 70 分钟。状态还行，想练全身再做一点有氧。',
  );
  bool _keyboard = false;
  bool _loading = false;
  bool _environmentLoading = true;
  List<WorkoutRecord> _records = const [];
  EnvironmentSnapshot? _environment;
  String? _environmentError;

  late final EnvironmentService _environmentService =
      widget.environmentService ?? LiveEnvironmentService();
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await WorkoutHistoryStore().migrateLegacyRecord();
    await Future.wait([_loadRecords(), _loadEnvironment()]);
  }

  Future<void> _loadRecords() async {
    final records = await WorkoutHistoryStore().load();
    if (!mounted) return;
    setState(() => _records = records);
  }

  Future<void> _loadEnvironment() async {
    final cached = await _environmentService.cached();
    if (mounted && cached != null) setState(() => _environment = cached);
    await _refreshEnvironment(showError: cached == null);
  }

  Future<void> _refreshEnvironment({bool showError = true}) async {
    if (mounted) {
      setState(() {
        _environmentLoading = true;
        _environmentError = null;
      });
    }
    try {
      final snapshot = await _environmentService.refresh();
      if (!mounted) return;
      setState(() => _environment = snapshot);
    } catch (error) {
      if (!mounted) return;
      final message = error is EnvironmentException
          ? error.message
          : '位置与天气更新失败';
      setState(() => _environmentError = message);
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message，点击状态栏可重试。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _environmentLoading = false);
    }
  }

  Future<void> _generate() async {
    HapticFeedback.selectionClick();
    setState(() => _loading = true);
    try {
      final plan = await _apiClient.generatePlan(_controller.text);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => PlanScreen(plan: plan)));
      await _loadRecords();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 计划生成失败，请稍后重试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openRecord(WorkoutRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SummaryScreen.fromRecord(record)),
    );
    await _loadRecords();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.date ?? DateTime.now();
    final latest = _records.firstOrNull;
    final todayRecord = latest != null && _isSameDay(latest.completedAt, today)
        ? latest
        : null;
    final hasTodayRecord = todayRecord != null;
    final dateLabel = homeDateLabel(today);
    final locationLabel =
        _environment?.locationLabel ??
        (_environmentLoading ? '正在定位…' : '定位未更新');
    final weatherLabel =
        _environment?.weatherLabel ??
        (_environmentLoading ? '天气同步中…' : '天气未更新');
    final humidityLabel = _environment?.humidityLabel ?? '湿度 --';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        container: true,
                        label: _environment == null ? '环境信息更新中' : '环境信息已更新',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusPill(
                              icon: Icons.location_on_outlined,
                              label: locationLabel,
                              onTap: _refreshEnvironment,
                            ),
                            _StatusPill(
                              icon: _weatherIcon(weatherLabel),
                              label: weatherLabel,
                              onTap: _refreshEnvironment,
                            ),
                            _StatusPill(
                              icon: Icons.water_drop_outlined,
                              label: humidityLabel,
                              onTap: _refreshEnvironment,
                            ),
                          ],
                        ),
                      ),
                      if (_environmentError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$_environmentError · 点击上方重试',
                          style: const TextStyle(
                            color: AppColors.orange,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: '个人中心',
                  child: Material(
                    color: AppColors.panelSoft,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => AccountScreen(
                            onLogout: widget.onLogout ?? () async {},
                          ),
                        ),
                      ),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: Icon(Icons.person_rounded)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              hasTodayRecord ? '今天练得不错。' : '今天怎么练？',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              hasTodayRecord ? '把这次状态留给下一次训练。' : '告诉我时间和状态，剩下的交给 AI。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (hasTodayRecord)
              _TodayRecord(
                sets: todayRecord.completedSets,
                seconds: todayRecord.durationSeconds,
                onOpen: () => _openRecord(todayRecord),
              )
            else if (_keyboard)
              _KeyboardEntry(
                controller: _controller,
                loading: _loading,
                onClose: () => setState(() => _keyboard = false),
                onGenerate: _generate,
              )
            else
              _VoiceEntry(
                loading: _loading,
                onVoice: _generate,
                onKeyboard: () => setState(() => _keyboard = true),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.grid_view_rounded,
                    color: AppColors.violet,
                    title: '动作库',
                    subtitle: '查看标准演示',
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const ExerciseLibraryScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionCard(
                    icon: hasTodayRecord
                        ? Icons.restart_alt_rounded
                        : Icons.play_arrow_rounded,
                    color: AppColors.lime,
                    title: hasTodayRecord ? '重新开练' : '快速开练',
                    subtitle: hasTodayRecord ? '重新生成今天的计划' : '60 分钟 · 全身',
                    onTap: _generate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '上一次训练',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                TextButton.icon(
                  onPressed: _records.isEmpty
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(records: _records),
                          ),
                        ),
                  label: const Text('查看历史'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LastSession(
              record: latest,
              onOpen: latest == null ? null : () => _openRecord(latest),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: '$label，点击刷新',
    child: Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.panel,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

String homeDateLabel(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${date.month} 月 ${date.day} 日 · ${weekdays[date.weekday - 1]}';
}

class _VoiceEntry extends StatelessWidget {
  const _VoiceEntry({
    required this.loading,
    required this.onVoice,
    required this.onKeyboard,
  });

  final bool loading;
  final VoidCallback onVoice;
  final VoidCallback onKeyboard;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      height: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4FF67), AppColors.lime, AppColors.limeDeep],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(right: -38, bottom: -58, child: _HeroRings()),
          Positioned.fill(
            child: InkWell(
              onTap: loading ? null : onVoice,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF11130D,
                            ).withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'AI COACH · 约 20 秒',
                            style: TextStyle(
                              color: Color(0xFF29340E),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .4,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: '切换到键盘输入',
                          child: Material(
                            color: const Color(
                              0xFF11130D,
                            ).withValues(alpha: .1),
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: onKeyboard,
                              tooltip: '键盘输入',
                              color: const Color(0xFF25300C),
                              icon: const Icon(Icons.keyboard_alt_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Color(0xFF11130D),
                        shape: BoxShape.circle,
                      ),
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: AppColors.lime,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.lime,
                              size: 31,
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      loading ? '正在理解你的状态…' : '快速生成今天计划',
                      style: const TextStyle(
                        color: Color(0xFF11130D),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '基于你的资料生成，也可先补充状态',
                      style: TextStyle(
                        color: Color(0xFF46541E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeroRings extends StatelessWidget {
  const _HeroRings();

  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    height: 170,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: const Color(0xFF11130D).withValues(alpha: .12),
        width: 26,
      ),
    ),
    child: Container(
      margin: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF11130D).withValues(alpha: .12),
          width: 16,
        ),
      ),
    ),
  );
}

class _KeyboardEntry extends StatelessWidget {
  const _KeyboardEntry({
    required this.controller,
    required this.loading,
    required this.onClose,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onClose;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '输入今天的状态',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            TextButton(onPressed: onClose, child: const Text('返回快速生成')),
          ],
        ),
        TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '时间、状态和想练的内容',
            border: InputBorder.none,
          ),
        ),
        FilledButton(
          onPressed: loading ? null : onGenerate,
          child: Text(loading ? '正在生成…' : '理解并生成计划  →'),
        ),
      ],
    ),
  );
}

class _TodayRecord extends StatelessWidget {
  const _TodayRecord({
    required this.sets,
    required this.seconds,
    required this.onOpen,
  });
  final int sets;
  final int seconds;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('today_record'),
    onTap: onOpen,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2116),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF3F4925)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.lime, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日训练已完成',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text('${_durationLabel(seconds)} · $sets 个有效组'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class _LastSession extends StatelessWidget {
  const _LastSession({required this.record, required this.onOpen});

  final WorkoutRecord? record;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (record == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: const Text(
          '还没有训练记录。完成第一次训练后，这里会显示真实数据。',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    final value = record!;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(
                      '${value.completedAt.day}'.padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${value.completedAt.month} 月',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '训练记录 · ${_durationLabel(value.durationSeconds)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${value.completedSets} 个有效组 · ${value.completedSetsByExercise.length} 个动作',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF182014),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: AppColors.lime),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '只展示本次真实完成的数据，点击查看训练总结。',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _durationLabel(int seconds) =>
    seconds < 60 ? '不足 1 分钟' : '${seconds ~/ 60} 分钟';

IconData _weatherIcon(String label) {
  if (label.contains('雨')) return Icons.umbrella_outlined;
  if (label.contains('雪')) return Icons.ac_unit_rounded;
  if (label.contains('云') || label.contains('雾')) {
    return Icons.cloud_outlined;
  }
  return Icons.wb_sunny_outlined;
}
