import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalPages = 8;
  final _controller = PageController();
  final _profile = UserProfile();
  int _page = 0;
  bool _listening = false;
  bool _recorded = false;

  void _next() {
    if (_page == _totalPages - 1) {
      widget.onCompleted();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _recordIntroduction() async {
    setState(() => _listening = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _listening = false;
      _recorded = true;
      _profile.spokenIntroduction = '我主要想增肌，比较喜欢器械训练，不太喜欢跑步。';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: (_page + 1) / _totalPages,
                  backgroundColor: AppColors.line,
                  color: AppColors.lime,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_page > 0)
                      Text(
                        '$_page / 7 · ${const ['性别', '生日', '身高', '体重', '训练经验', '身体限制', '可选'][_page - 1]}',
                        style: const TextStyle(
                          color: AppColors.lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      const SizedBox(),
                    if (_page > 0)
                      TextButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.chevron_left, size: 16),
                        label: const Text('返回'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() => _page = value),
                  children: [
                    _WelcomePage(onNext: _next),
                    _QuestionPage(
                      title: '怎么称呼你的\n身体数据？',
                      description: '用于估算基础消耗和推荐强度，不影响你选择任何训练内容。',
                      onNext: _next,
                      child: _ChoiceRow(
                        values: const ['男', '女'],
                        selected: _profile.sex,
                        onChanged: (value) =>
                            setState(() => _profile.sex = value),
                      ),
                    ),
                    _QuestionPage(
                      title: '你的生日是？',
                      description: '年龄会影响训练恢复和强度建议。生日仅用于个性化计算。',
                      onNext: _next,
                      child: _BirthdayPicker(
                        profile: _profile,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    _QuestionPage(
                      title: '你的身高是？',
                      description: '和体重一起用于估算动作起点，之后可以随时修改。',
                      onNext: _next,
                      child: _NumberStepper(
                        value: _profile.heightCm,
                        unit: 'cm',
                        min: 120,
                        max: 220,
                        onChanged: (value) =>
                            setState(() => _profile.heightCm = value),
                      ),
                    ),
                    _QuestionPage(
                      title: '你的体重是？',
                      description: '用于估算动作负荷与训练消耗，不会公开展示。',
                      onNext: _next,
                      child: _NumberStepper(
                        value: _profile.weightKg,
                        unit: 'kg',
                        min: 35,
                        max: 200,
                        onChanged: (value) =>
                            setState(() => _profile.weightKg = value),
                      ),
                    ),
                    _QuestionPage(
                      title: '今天从合适的\n起点开始。',
                      description: '不做测试，也不要求你承诺每周练几次。',
                      onNext: _next,
                      child: _ChoiceList(
                        values: const ['刚开始', '练过一阵', '比较熟悉'],
                        descriptions: const {
                          '刚开始': '需要更多动作提示',
                          '练过一阵': '知道常见动作和器械',
                          '比较熟悉': '可以自主判断训练强度',
                        },
                        selected: _profile.experience,
                        onChanged: (value) =>
                            setState(() => _profile.experience = value),
                      ),
                    ),
                    _QuestionPage(
                      title: '有需要避开的\n部位吗？',
                      description: '我们会优先避开容易引起不适的动作，也可以选择暂无。',
                      onNext: _next,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '需要避开的部位',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _CompactChoiceRow(
                            values: const ['暂无', '膝盖', '腰背', '肩颈'],
                            selected: _profile.limitation,
                            onChanged: (value) =>
                                setState(() => _profile.limitation = value),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '身体不适或处于康复期时，请先咨询医生或康复师。',
                            style: TextStyle(
                              color: Color(0xFF6F7680),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _OptionalVoicePage(
                      listening: _listening,
                      recorded: _recorded,
                      onRecord: _recordIntroduction,
                      onReset: () => setState(() => _recorded = false),
                      onDone: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 42),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/branding/logo.png',
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        ),
        const Spacer(),
        const Text(
          '欢迎来到随练 AI',
          style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          '不用坚持打卡，\n每次来都能练。',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 16),
        Text(
          '告诉我一点基础情况。以后到了健身房，只要说时间和状态，就能直接开练。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        const _WelcomeValue(value: '20 秒', label: '生成今天的训练'),
        const SizedBox(height: 8),
        const _WelcomeValue(value: '1 句话', label: '随时调整计划'),
        const SizedBox(height: 8),
        const _WelcomeValue(value: '每一组', label: '都会被记住'),
        const SizedBox(height: 22),
        FilledButton(onPressed: onNext, child: const Text('开始设置  →')),
      ],
    ),
  );
}

class _WelcomeValue extends StatelessWidget {
  const _WelcomeValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF171A1F),
      border: Border.all(color: const Color(0xFF292D34)),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.title,
    required this.description,
    required this.child,
    required this.onNext,
  });
  final String title;
  final String description;
  final Widget child;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 14),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        child,
        const Spacer(),
        FilledButton(onPressed: onNext, child: const Text('继续  →')),
      ],
    ),
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: values
        .map(
          (value) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: value == values.last ? 0 : 10),
              child: _ChoiceTile(
                value: value,
                selected: value == selected,
                onTap: () => onChanged(value),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.values,
    required this.selected,
    required this.onChanged,
    this.descriptions = const {},
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  final Map<String, String> descriptions;
  @override
  Widget build(BuildContext context) => Column(
    children: values
        .map(
          (value) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceTile(
              value: value,
              selected: value == selected,
              onTap: () => onChanged(value),
              compact: true,
              description: descriptions[value],
            ),
          ),
        )
        .toList(),
  );
}

class _CompactChoiceRow extends StatelessWidget {
  const _CompactChoiceRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: values
        .map(
          (value) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: value == values.last ? 0 : 7),
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected
                        ? const Color(0xFF22291A)
                        : AppColors.panel,
                    border: Border.all(
                      color: value == selected
                          ? AppColors.lime
                          : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: value == selected
                          ? AppColors.lime
                          : AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.value,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.description,
  });
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final String? description;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      height: compact ? 62 : 120,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF22291A) : AppColors.panel,
        border: Border.all(color: selected ? AppColors.lime : AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          if (compact && description != null)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: selected ? AppColors.lime : AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                color: selected ? AppColors.lime : AppColors.text,
                fontSize: compact ? 16 : 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (compact)
            Icon(
              Icons.check_circle,
              color: selected ? AppColors.lime : AppColors.line,
            ),
        ],
      ),
    ),
  );
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final String unit;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.panel,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: () => onChanged((value - 1).clamp(min, max)),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$value',
              children: [
                TextSpan(
                  text: '  $unit',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: () => onChanged((value + 1).clamp(min, max)),
        ),
      ],
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton.filled(
    onPressed: onTap,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      backgroundColor: AppColors.panelSoft,
      foregroundColor: AppColors.text,
      minimumSize: const Size(58, 58),
    ),
  );
}

class _BirthdayPicker extends StatelessWidget {
  const _BirthdayPicker({required this.profile, required this.onChanged});
  final UserProfile profile;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final birthday = profile.birthday;
    final daysInMonth = DateUtils.getDaysInMonth(birthday.year, birthday.month);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 135,
              child: _BirthdayField(
                label: '年份',
                value: birthday.year,
                values: List.generate(73, (index) => 2008 - index),
                onChanged: (year) => _updateDate(
                  year ?? birthday.year,
                  birthday.month,
                  birthday.day,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 80,
              child: _BirthdayField(
                label: '月份',
                value: birthday.month,
                values: List.generate(12, (index) => index + 1),
                onChanged: (month) => _updateDate(
                  birthday.year,
                  month ?? birthday.month,
                  birthday.day,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 80,
              child: _BirthdayField(
                label: '日期',
                value: birthday.day.clamp(1, daysInMonth),
                values: List.generate(daysInMonth, (index) => index + 1),
                onChanged: (day) => _updateDate(
                  birthday.year,
                  birthday.month,
                  day ?? birthday.day,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('当前年龄', style: TextStyle(color: AppColors.muted)),
              Text(
                '${profile.ageAt(DateTime(2026, 7, 12))} 岁',
                style: const TextStyle(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateDate(int year, int month, int day) {
    final safeDay = day.clamp(1, DateUtils.getDaysInMonth(year, month));
    profile.birthday = DateTime(year, month, safeDay);
    onChanged();
  }
}

class _BirthdayField extends StatelessWidget {
  const _BirthdayField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 7),
      DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: AppColors.panelSoft,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF1C2025),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.lime),
          ),
        ),
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        items: values
            .map(
              (item) => DropdownMenuItem<int>(
                value: item,
                child: Text('$item', textAlign: TextAlign.center),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _OptionalVoicePage extends StatelessWidget {
  const _OptionalVoicePage({
    required this.listening,
    required this.recorded,
    required this.onRecord,
    required this.onReset,
    required this.onDone,
  });
  final bool listening;
  final bool recorded;
  final VoidCallback onRecord;
  final VoidCallback onReset;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('还有什么想让\n我了解的吗？', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 14),
        Text(
          '可以简单介绍训练目标、喜欢或不喜欢的动作。这一步完全可选。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        if (!recorded)
          InkWell(
            onTap: onRecord,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2217),
                border: Border.all(
                  color: listening ? AppColors.lime : const Color(0xFF485528),
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF11130D),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    listening ? '正在听…' : '按住说话',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '例如：想增肌，不喜欢跑步',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2217),
              border: Border.all(color: const Color(0xFF485528)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '✓ 已记录',
                      style: TextStyle(
                        color: AppColors.lime,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(onPressed: onReset, child: const Text('重录')),
                  ],
                ),
                const Text(
                  '我主要想增肌，比较喜欢器械训练，不太喜欢跑步。',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 7,
                  children: [_Tag('增肌'), _Tag('偏好器械'), _Tag('不喜欢跑步')],
                ),
              ],
            ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: onDone,
          child: Text(recorded ? '保存并开始训练  →' : '跳过，开始训练  →'),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF29321B),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.lime, fontSize: 10),
      ),
    ),
  );
}
