class WorkoutExercise {
  const WorkoutExercise({
    required this.slug,
    required this.name,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restSeconds,
    required this.loadKg,
    required this.cue,
  });

  final String slug;
  final String name;
  final int sets;
  final int repsMin;
  final int repsMax;
  final int restSeconds;
  final double loadKg;
  final String cue;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final slug = json['exercise_slug'] as String;
    return WorkoutExercise(
      slug: slug,
      name: exerciseNames[slug] ?? slug,
      sets: (json['sets'] as num?)?.toInt() ?? 1,
      repsMin: (json['reps_min'] as num?)?.toInt() ?? 10,
      repsMax: (json['reps_max'] as num?)?.toInt() ?? 12,
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 90,
      loadKg: (json['suggested_load_kg'] as num?)?.toDouble() ?? 0,
      cue: json['cue'] as String? ?? '',
    );
  }
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.goalSummary,
    required this.coachMessage,
    required this.estimatedMinutes,
    required this.source,
    required this.exercises,
  });

  final String id;
  final String title;
  final String goalSummary;
  final String coachMessage;
  final int estimatedMinutes;
  final String source;
  final List<WorkoutExercise> exercises;

  WorkoutPlan copyWith({
    String? id,
    String? title,
    String? goalSummary,
    String? coachMessage,
    int? estimatedMinutes,
    String? source,
    List<WorkoutExercise>? exercises,
  }) => WorkoutPlan(
    id: id ?? this.id,
    title: title ?? this.title,
    goalSummary: goalSummary ?? this.goalSummary,
    coachMessage: coachMessage ?? this.coachMessage,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    source: source ?? this.source,
    exercises: exercises ?? this.exercises,
  );

  factory WorkoutPlan.fromEnvelope(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>;
    return WorkoutPlan(
      id: plan['plan_id'] as String,
      title: plan['title'] as String,
      goalSummary: plan['goal_summary'] as String,
      coachMessage: plan['coach_message'] as String,
      estimatedMinutes: (plan['estimated_minutes'] as num).toInt(),
      source: json['source'] as String? ?? 'remote',
      exercises: (plan['exercises'] as List<dynamic>)
          .map((item) => WorkoutExercise.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

const exerciseNames = {
  'leg_press': '腿举',
  'machine_chest_press': '器械推胸',
  'lat_pulldown': '高位下拉',
  'machine_leg_curl': '坐姿腿弯举',
  'incline_treadmill_walk': '跑步机快走',
};

const exerciseAssets = {
  'leg_press': 'assets/exercises/leg_press.png',
  'machine_chest_press': 'assets/exercises/machine_chest_press.jpg',
  'lat_pulldown': 'assets/exercises/lat_pulldown.jpg',
  'machine_leg_curl': 'assets/exercises/machine_leg_curl.jpg',
  'incline_treadmill_walk': 'assets/exercises/incline_treadmill_walk.jpg',
};
