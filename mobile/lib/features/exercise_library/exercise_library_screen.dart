import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise_catalog.dart';
import '../../theme/app_theme.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    this.initialMuscle = '胸部',
    this.currentSlug,
    this.selectionMode = false,
  });

  final String initialMuscle;
  final String? currentSlug;
  final bool selectionMode;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  late String _muscle;
  ExerciseEquipment? _equipment;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _muscle =
        exerciseCatalog.any((entry) => entry.muscle == widget.initialMuscle)
        ? widget.initialMuscle
        : '全部';
  }

  List<ExerciseCatalogEntry> get _results => exerciseCatalog.where((entry) {
    final matchesMuscle = _muscle == '全部' || entry.muscle == _muscle;
    final matchesEquipment =
        _equipment == null || entry.equipment == _equipment;
    final query = _query.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        entry.name.toLowerCase().contains(query) ||
        entry.equipment.label.contains(query);
    return matchesMuscle && matchesEquipment && matchesQuery;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final muscles = <String>{'全部', ...exerciseCatalog.map((e) => e.muscle)};
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2B341A), Color(0xFF171C20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF455323)),
                      ),
                      child: const Row(
                        children: [
                          _MascotBadge(),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '想练哪里？',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '按肌群和器械筛选，再看动作演示。',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: '搜索动作或器械',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _FilterTitle(
                      icon: Icons.my_location_rounded,
                      label: '目标肌群',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: muscles
                          .map(
                            (muscle) => FilterChip(
                              label: Text(muscle),
                              selected: _muscle == muscle,
                              onSelected: (_) =>
                                  setState(() => _muscle = muscle),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const _FilterTitle(icon: Icons.tune_rounded, label: '器械类型'),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('全部'),
                              selected: _equipment == null,
                              onSelected: (_) =>
                                  setState(() => _equipment = null),
                            ),
                          ),
                          ...ExerciseEquipment.values
                              .where(
                                (equipment) => exerciseCatalog.any(
                                  (entry) => entry.equipment == equipment,
                                ),
                              )
                              .map(
                                (equipment) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    avatar: Icon(equipment.icon),
                                    label: Text(equipment.label),
                                    selected: _equipment == equipment,
                                    onSelected: (_) => setState(
                                      () => _equipment = _equipment == equipment
                                          ? null
                                          : equipment,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          '找到 ${results.length} 个动作',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '点击查看演示',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (results.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ExerciseCard(
                    entry: results[index],
                    selected: results[index].slug == widget.currentSlug,
                    onTap: () => _showDetails(results[index]),
                    onSelect: widget.selectionMode
                        ? () => Navigator.pop(context, results[index])
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetails(ExerciseCatalogEntry entry) async {
    final selected = await Navigator.of(context).push<ExerciseCatalogEntry>(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          entry: entry,
          isCurrent: entry.slug == widget.currentSlug,
          selectionMode: widget.selectionMode,
        ),
      ),
    );
    if (selected != null && mounted) Navigator.pop(context, selected);
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.entry,
    this.isCurrent = false,
    this.selectionMode = false,
  });

  final ExerciseCatalogEntry entry;
  final bool isCurrent;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(entry.name)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          AnimatedExercisePreview(entry: entry),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(icon: Icons.my_location_rounded, label: entry.muscle),
              _Tag(icon: entry.equipment.icon, label: entry.equipment.label),
              _Tag(icon: Icons.bolt_rounded, label: entry.level),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '动作步骤',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...entry.instructions.indexed.map(
            (item) => _Instruction(index: item.$1 + 1, text: item.$2),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF201C2C),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF493B67)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, color: AppColors.violet),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(entry.cue, style: const TextStyle(height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '动作资料来自 free-exercise-db（Public Domain / Unlicense）。身体不适时请停止动作并咨询专业人士。',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: FilledButton.icon(
          onPressed: isCurrent
              ? null
              : () => Navigator.pop(context, selectionMode ? entry : null),
          icon: Icon(
            isCurrent
                ? Icons.check_rounded
                : selectionMode
                ? Icons.swap_horiz_rounded
                : Icons.arrow_back_rounded,
          ),
          label: Text(
            isCurrent
                ? '当前正在使用'
                : selectionMode
                ? '换成这个动作'
                : '返回动作库',
          ),
        ),
      ),
    ),
  );
}

class AnimatedExercisePreview extends StatefulWidget {
  const AnimatedExercisePreview({super.key, required this.entry});

  final ExerciseCatalogEntry entry;

  @override
  State<AnimatedExercisePreview> createState() =>
      _AnimatedExercisePreviewState();
}

class _AnimatedExercisePreviewState extends State<AnimatedExercisePreview> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.entry.images.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) {
          setState(() => _frame = (_frame + 1) % widget.entry.images.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${widget.entry.name}动作演示，第 ${_frame + 1} 帧',
    image: true,
    child: Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFEA),
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Image.asset(
              widget.entry.images[_frame],
              key: ValueKey(_frame),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xD911130D),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 16,
                    color: AppColors.lime,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '双阶段演示',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onSelect,
  });

  final ExerciseCatalogEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF252E1B) : AppColors.panel,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.lime : AppColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                entry.images.first,
                width: 96,
                height: 82,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                semanticLabel: '${entry.name}起始姿势',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        entry.equipment.icon,
                        size: 15,
                        color: _equipmentColor(entry.equipment),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${entry.equipment.label} · ${entry.level}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${entry.repsMin}–${entry.repsMax} 次 · 休息 ${entry.restSeconds} 秒',
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onSelect != null)
              IconButton(
                tooltip: selected ? '当前动作' : '选择 ${entry.name}',
                onPressed: selected ? null : onSelect,
                icon: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_rounded,
                  color: selected ? AppColors.lime : AppColors.sky,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _MascotBadge extends StatelessWidget {
  const _MascotBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: AppColors.lime,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x4DD8FF3E),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.fitness_center_rounded, color: Color(0xFF11130D), size: 32),
        Positioned(
          right: 8,
          top: 8,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF11130D),
            size: 14,
          ),
        ),
      ],
    ),
  );
}

class _FilterTitle extends StatelessWidget {
  const _FilterTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.lime),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.panelSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.sky, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF25321C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: AppColors.lime,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.55))),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: AppColors.muted),
          SizedBox(height: 12),
          Text('暂时没有匹配动作', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('换个关键词或清除器械筛选试试', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}

Color _equipmentColor(ExerciseEquipment equipment) => switch (equipment) {
  ExerciseEquipment.machine => AppColors.sky,
  ExerciseEquipment.dumbbell => AppColors.coral,
  ExerciseEquipment.barbell => AppColors.violet,
  ExerciseEquipment.bodyweight => AppColors.lime,
  ExerciseEquipment.cable => AppColors.orange,
  ExerciseEquipment.cardio => AppColors.sky,
};
