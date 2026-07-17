import 'package:flutter/material.dart';

import 'workout_plan.dart';

enum ExerciseEquipment {
  machine('器械', Icons.precision_manufacturing_rounded),
  dumbbell('哑铃', Icons.fitness_center_rounded),
  barbell('杠铃', Icons.horizontal_rule_rounded),
  bodyweight('自重', Icons.accessibility_new_rounded),
  cable('绳索', Icons.cable_rounded),
  cardio('有氧器械', Icons.directions_run_rounded);

  const ExerciseEquipment(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ExerciseCatalogEntry {
  const ExerciseCatalogEntry({
    required this.slug,
    required this.sourceId,
    required this.name,
    required this.muscle,
    required this.equipment,
    required this.level,
    required this.images,
    required this.instructions,
    required this.cue,
    required this.defaultLoadKg,
    this.repsMin = 8,
    this.repsMax = 12,
    this.restSeconds = 90,
  });

  final String slug;
  final String sourceId;
  final String name;
  final String muscle;
  final ExerciseEquipment equipment;
  final String level;
  final List<String> images;
  final List<String> instructions;
  final String cue;
  final double defaultLoadKg;
  final int repsMin;
  final int repsMax;
  final int restSeconds;

  WorkoutExercise replace(WorkoutExercise current) => WorkoutExercise(
    slug: slug,
    name: name,
    sets: current.sets,
    repsMin: repsMin,
    repsMax: repsMax,
    restSeconds: restSeconds,
    loadKg: defaultLoadKg,
    cue: cue,
  );
}

const _assetRoot = 'assets/exercise_library';

const exerciseCatalog = <ExerciseCatalogEntry>[
  ExerciseCatalogEntry(
    slug: 'machine_chest_press',
    sourceId: 'Leverage_Chest_Press',
    name: '器械推胸',
    muscle: '胸部',
    equipment: ExerciseEquipment.machine,
    level: '入门友好',
    images: [
      '$_assetRoot/leverage-chest-press_0.jpg',
      '$_assetRoot/leverage-chest-press_1.jpg',
    ],
    instructions: ['调整座椅，让把手与胸部中线齐平。', '肩胛向后下方收紧，推出时不要耸肩。', '缓慢回到起点，保持胸部持续发力。'],
    cue: '肩胛稳定，不耸肩，回程保持控制。',
    defaultLoadKg: 30,
  ),
  ExerciseCatalogEntry(
    slug: 'pec_deck_fly',
    sourceId: 'Butterfly',
    name: '蝴蝶机夹胸',
    muscle: '胸部',
    equipment: ExerciseEquipment.machine,
    level: '入门友好',
    images: ['$_assetRoot/butterfly_0.jpg', '$_assetRoot/butterfly_1.jpg'],
    instructions: ['背部贴紧靠垫，手肘与肩部大致同高。', '像抱住大树一样把手臂向胸前合拢。', '停顿后慢慢打开，不让配重撞击。'],
    cue: '用胸去合拢手臂，不要用手腕硬推。',
    defaultLoadKg: 25,
    repsMin: 10,
    repsMax: 15,
    restSeconds: 75,
  ),
  ExerciseCatalogEntry(
    slug: 'machine_incline_chest_press',
    sourceId: 'Leverage_Incline_Chest_Press',
    name: '上斜器械推胸',
    muscle: '胸部',
    equipment: ExerciseEquipment.machine,
    level: '入门友好',
    images: [
      '$_assetRoot/leverage-incline-chest-press_0.jpg',
      '$_assetRoot/leverage-incline-chest-press_1.jpg',
    ],
    instructions: ['让把手起点位于上胸两侧。', '脚掌踩稳，肩胛贴紧靠垫。', '向前上方推起，肘部不要完全锁死。'],
    cue: '把力量送向上胸，肩膀不要向前顶。',
    defaultLoadKg: 25,
  ),
  ExerciseCatalogEntry(
    slug: 'dumbbell_bench_press',
    sourceId: 'Dumbbell_Bench_Press',
    name: '哑铃卧推',
    muscle: '胸部',
    equipment: ExerciseEquipment.dumbbell,
    level: '入门友好',
    images: [
      '$_assetRoot/dumbbell-bench-press_0.jpg',
      '$_assetRoot/dumbbell-bench-press_1.jpg',
    ],
    instructions: [
      '双脚踩稳，肩胛向后下方固定。',
      '哑铃落到胸部两侧，肘部与身体约成 45°。',
      '垂直推起，在顶部保持手腕稳定。',
    ],
    cue: '肘部别打开成一条直线，手腕始终叠在肘部上方。',
    defaultLoadKg: 12,
  ),
  ExerciseCatalogEntry(
    slug: 'incline_dumbbell_press',
    sourceId: 'Incline_Dumbbell_Press',
    name: '上斜哑铃卧推',
    muscle: '胸部',
    equipment: ExerciseEquipment.dumbbell,
    level: '入门友好',
    images: [
      '$_assetRoot/incline-dumbbell-press_0.jpg',
      '$_assetRoot/incline-dumbbell-press_1.jpg',
    ],
    instructions: ['将训练凳调到约 30°。', '哑铃从上胸两侧开始，肩胛保持稳定。', '向上推起并缓慢下降，避免哑铃碰撞。'],
    cue: '凳子不要太陡，优先感受上胸而不是肩前束。',
    defaultLoadKg: 10,
  ),
  ExerciseCatalogEntry(
    slug: 'dumbbell_fly',
    sourceId: 'Dumbbell_Flyes',
    name: '哑铃飞鸟',
    muscle: '胸部',
    equipment: ExerciseEquipment.dumbbell,
    level: '需要控制',
    images: [
      '$_assetRoot/dumbbell-flyes_0.jpg',
      '$_assetRoot/dumbbell-flyes_1.jpg',
    ],
    instructions: ['用明显轻于卧推的重量开始。', '保持手肘微屈，沿弧线打开双臂。', '胸部有拉伸感后合拢，不追求过深幅度。'],
    cue: '全程保持同样的肘部角度，避免肩前侧不适。',
    defaultLoadKg: 6,
    repsMin: 10,
    repsMax: 15,
    restSeconds: 75,
  ),
  ExerciseCatalogEntry(
    slug: 'barbell_bench_press',
    sourceId: 'Barbell_Bench_Press_-_Medium_Grip',
    name: '杠铃卧推',
    muscle: '胸部',
    equipment: ExerciseEquipment.barbell,
    level: '基础进阶',
    images: [
      '$_assetRoot/barbell-bench-press---medium-grip_0.jpg',
      '$_assetRoot/barbell-bench-press---medium-grip_1.jpg',
    ],
    instructions: ['眼睛位于杠铃正下方，双脚踩稳。', '收紧肩胛，把杠铃下放到胸部中下段。', '沿略向后的轨迹推起，始终握紧杠铃。'],
    cue: '先固定肩胛再出杠，最好让同伴保护。',
    defaultLoadKg: 40,
    repsMin: 6,
    repsMax: 10,
    restSeconds: 120,
  ),
  ExerciseCatalogEntry(
    slug: 'incline_barbell_bench_press',
    sourceId: 'Barbell_Incline_Bench_Press_-_Medium_Grip',
    name: '上斜杠铃卧推',
    muscle: '胸部',
    equipment: ExerciseEquipment.barbell,
    level: '基础进阶',
    images: [
      '$_assetRoot/barbell-incline-bench-press---medium-grip_0.jpg',
      '$_assetRoot/barbell-incline-bench-press---medium-grip_1.jpg',
    ],
    instructions: ['将训练凳调到约 30°，脚掌踩稳。', '杠铃下放到锁骨下方的上胸位置。', '保持肩胛稳定，向上推起。'],
    cue: '上斜角度适中，避免动作变成肩推。',
    defaultLoadKg: 30,
    repsMin: 6,
    repsMax: 10,
    restSeconds: 120,
  ),
  ExerciseCatalogEntry(
    slug: 'decline_barbell_bench_press',
    sourceId: 'Decline_Barbell_Bench_Press',
    name: '下斜杠铃卧推',
    muscle: '胸部',
    equipment: ExerciseEquipment.barbell,
    level: '基础进阶',
    images: [
      '$_assetRoot/decline-barbell-bench-press_0.jpg',
      '$_assetRoot/decline-barbell-bench-press_1.jpg',
    ],
    instructions: ['固定双腿并确认器械安全。', '把杠铃下放到胸部下缘。', '稳定推起，不让手腕向后折。'],
    cue: '下斜位出杠不便，建议使用保护杆或同伴保护。',
    defaultLoadKg: 40,
    repsMin: 6,
    repsMax: 10,
    restSeconds: 120,
  ),
  ExerciseCatalogEntry(
    slug: 'push_up',
    sourceId: 'Pushups',
    name: '标准俯卧撑',
    muscle: '胸部',
    equipment: ExerciseEquipment.bodyweight,
    level: '随时可练',
    images: ['$_assetRoot/pushups_0.jpg', '$_assetRoot/pushups_1.jpg'],
    instructions: ['双手略宽于肩，身体从头到脚保持直线。', '屈肘下降，肘部与身体约成 45°。', '胸部接近地面后推回起点。'],
    cue: '收紧腹部和臀部，不要塌腰或耸肩。',
    defaultLoadKg: 0,
    repsMin: 8,
    repsMax: 15,
    restSeconds: 75,
  ),
  ExerciseCatalogEntry(
    slug: 'incline_push_up',
    sourceId: 'Incline_Push-Up',
    name: '上斜俯卧撑',
    muscle: '胸部',
    equipment: ExerciseEquipment.bodyweight,
    level: '新手首选',
    images: [
      '$_assetRoot/incline-push-up_0.jpg',
      '$_assetRoot/incline-push-up_1.jpg',
    ],
    instructions: ['双手撑在稳定的长凳或高台上。', '身体保持一条直线，胸部靠近支撑面。', '推回起点，逐渐降低支撑高度来进阶。'],
    cue: '支撑越高越轻松，先保证身体不塌腰。',
    defaultLoadKg: 0,
    repsMin: 10,
    repsMax: 20,
    restSeconds: 60,
  ),
  ExerciseCatalogEntry(
    slug: 'decline_push_up',
    sourceId: 'Push-Ups_With_Feet_Elevated',
    name: '脚抬高俯卧撑',
    muscle: '胸部',
    equipment: ExerciseEquipment.bodyweight,
    level: '进阶挑战',
    images: [
      '$_assetRoot/push-ups-with-feet-elevated_0.jpg',
      '$_assetRoot/push-ups-with-feet-elevated_1.jpg',
    ],
    instructions: ['双脚放在稳定高台，双手略宽于肩。', '保持核心收紧，胸部向地面下降。', '推回起点，避免头部先抬起。'],
    cue: '脚越高难度越大，肩前侧不适时改做标准俯卧撑。',
    defaultLoadKg: 0,
    repsMin: 6,
    repsMax: 12,
    restSeconds: 90,
  ),
];

ExerciseCatalogEntry? catalogEntryForSlug(String slug) {
  for (final entry in exerciseCatalog) {
    if (entry.slug == slug) return entry;
  }
  return null;
}

String exerciseImageAsset(String slug) =>
    exerciseAssets[slug] ??
    catalogEntryForSlug(slug)?.images.first ??
    exerciseAssets['leg_press']!;

String muscleForExercise(String slug) => switch (slug) {
  'machine_chest_press' ||
  'pec_deck_fly' ||
  'machine_incline_chest_press' ||
  'dumbbell_bench_press' ||
  'incline_dumbbell_press' ||
  'dumbbell_fly' ||
  'barbell_bench_press' ||
  'incline_barbell_bench_press' ||
  'decline_barbell_bench_press' ||
  'push_up' ||
  'incline_push_up' ||
  'decline_push_up' => '胸部',
  'lat_pulldown' => '背部',
  'leg_press' || 'machine_leg_curl' => '腿部',
  'incline_treadmill_walk' => '有氧',
  _ => '全身',
};
