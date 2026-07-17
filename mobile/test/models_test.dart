import 'package:flutter_test/flutter_test.dart';
import 'package:suilian_ai/models/workout_plan.dart';
import 'package:suilian_ai/services/api_client.dart';

void main() {
  test('parses a workout plan envelope', () {
    final plan = WorkoutPlan.fromEnvelope({
      'source': 'deterministic_fallback',
      'plan': {
        'plan_id': 'plan_test',
        'title': '恢复型训练',
        'goal_summary': '找回节奏',
        'coach_message': '动作稳定优先',
        'estimated_minutes': 30,
        'exercises': [
          {
            'exercise_slug': 'leg_press',
            'sets': 3,
            'reps_min': 10,
            'reps_max': 12,
            'rest_seconds': 90,
            'suggested_load_kg': 65,
            'cue': '保持稳定',
          },
        ],
      },
    });
    expect(plan.title, '恢复型训练');
    expect(plan.exercises.single.name, '腿举');
    expect(plan.exercises.single.loadKg, 65);
  });

  test('offline fallback respects requested duration', () {
    final plan = fallbackPlan(35);
    expect(plan.estimatedMinutes, 35);
    expect(plan.source, 'local_fallback');
    expect(plan.exercises, hasLength(3));
  });

  test('full offline fallback keeps the complete demo exercise sequence', () {
    final plan = fallbackPlan(70);
    expect(plan.estimatedMinutes, 68);
    expect(plan.exercises, hasLength(5));
    expect(plan.exercises.last.slug, 'incline_treadmill_walk');
    expect(
      plan.exercises
          .where((exercise) => exercise.slug != 'incline_treadmill_walk')
          .fold<int>(0, (sum, exercise) => sum + exercise.sets),
      11,
    );
  });
}
