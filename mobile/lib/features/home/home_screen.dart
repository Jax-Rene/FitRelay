import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../plan/plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.date});

  final DateTime? date;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController(
    text: '一周没练，今天有 70 分钟。状态还行，想练全身再做一点有氧。',
  );
  bool _keyboard = false;
  bool _loading = false;
  int? _lastSets;
  int? _lastMinutes;

  @override
  void initState() {
    super.initState();
    _loadLastRecord();
  }

  Future<void> _loadLastRecord() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final seconds = preferences.getInt('last_duration_seconds');
    setState(() {
      _lastSets = preferences.getInt('last_completed_sets');
      _lastMinutes = seconds == null ? null : seconds ~/ 60;
    });
  }

  Future<void> _generate() async {
    HapticFeedback.selectionClick();
    setState(() => _loading = true);
    final plan = await ApiClient().generatePlan(_controller.text);
    if (!mounted) return;
    setState(() => _loading = false);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PlanScreen(plan: plan)));
    await _loadLastRecord();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTodayRecord = _lastSets != null;
    final dateLabel = homeDateLabel(widget.date ?? DateTime.now());
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
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusPill(
                            icon: Icons.location_on_outlined,
                            label: '上海 · 徐汇',
                          ),
                          _StatusPill(
                            icon: Icons.wb_sunny_outlined,
                            label: '晴 31°',
                          ),
                        ],
                      ),
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
                      onTap: () => ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('个人设置即将开放'))),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Text(
                            '堂',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
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
                sets: _lastSets!,
                minutes: _lastMinutes ?? 0,
                onOpen: _generate,
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
                    icon: Icons.replay_rounded,
                    color: AppColors.lime,
                    title: '沿用上次',
                    subtitle: '60 分钟 · 全身',
                    onTap: _generate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '上一次训练',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: [
                    Text(
                      '查看历史',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.muted,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _LastSession(),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.panel,
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
                              Icons.graphic_eq_rounded,
                              color: AppColors.lime,
                              size: 31,
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      loading ? '正在理解你的状态…' : '说出今天的状态',
                      style: const TextStyle(
                        color: Color(0xFF11130D),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '时间 · 精力 · 想练的部位',
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
            TextButton(onPressed: onClose, child: const Text('语音输入')),
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
    required this.minutes,
    required this.onOpen,
  });
  final int sets;
  final int minutes;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
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
                Text('$minutes 分钟 · $sets 个有效组'),
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
  const _LastSession();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  '05',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  '7 月',
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
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
                  '全身力量 · 62 分钟',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  '15 个有效组 · 4 个主要肌群',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
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
            Icon(Icons.north_east, color: AppColors.lime),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '高位下拉在相同重量下，比上次多完成 3 次',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
