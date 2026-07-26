import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.completedAt,
    required this.durationSeconds,
    required this.completedSets,
    required this.completedSetsByExercise,
  });

  final String id;
  final DateTime completedAt;
  final int durationSeconds;
  final int completedSets;
  final Map<String, int> completedSetsByExercise;

  Map<String, dynamic> toJson() => {
    'id': id,
    'completed_at_ms': completedAt.millisecondsSinceEpoch,
    'duration_seconds': durationSeconds,
    'completed_sets': completedSets,
    'completed_sets_by_exercise': completedSetsByExercise,
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) => WorkoutRecord(
    id: json['id'] as String,
    completedAt: DateTime.fromMillisecondsSinceEpoch(
      json['completed_at_ms'] as int,
    ),
    durationSeconds: json['duration_seconds'] as int,
    completedSets: json['completed_sets'] as int,
    completedSetsByExercise:
        (json['completed_sets_by_exercise'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, value as int),
        ),
  );
}

class WorkoutHistoryStore {
  static const _recordsKey = 'workout_records_v1';

  Future<List<WorkoutRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final records = <WorkoutRecord>[];
    for (final raw in preferences.getStringList(_recordsKey) ?? const []) {
      try {
        records.add(
          WorkoutRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return records;
  }

  Future<void> save(WorkoutRecord record) async {
    if (record.completedSets <= 0 || record.durationSeconds <= 0) return;
    final preferences = await SharedPreferences.getInstance();
    final records = await load();
    final updated = [
      record,
      ...records.where((item) => item.id != record.id),
    ].take(100).map((item) => jsonEncode(item.toJson())).toList();
    await preferences.setStringList(_recordsKey, updated);

    // Keep the legacy keys during the data migration so existing installs do
    // not lose their most recent workout.
    await preferences.setInt('last_completed_sets', record.completedSets);
    await preferences.setInt('last_duration_seconds', record.durationSeconds);
    await preferences.setInt(
      'last_completed_at_ms',
      record.completedAt.millisecondsSinceEpoch,
    );
  }

  Future<void> migrateLegacyRecord() async {
    final preferences = await SharedPreferences.getInstance();
    if ((preferences.getStringList(_recordsKey) ?? const []).isNotEmpty) return;
    final sets = preferences.getInt('last_completed_sets');
    final seconds = preferences.getInt('last_duration_seconds');
    final completedAt = preferences.getInt('last_completed_at_ms');
    if (sets == null || seconds == null || completedAt == null) return;
    await save(
      WorkoutRecord(
        id: 'legacy_$completedAt',
        completedAt: DateTime.fromMillisecondsSinceEpoch(completedAt),
        durationSeconds: seconds,
        completedSets: sets,
        completedSetsByExercise: const {},
      ),
    );
  }
}
