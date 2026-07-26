import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_record.dart';
import '../models/workout_plan.dart';

class ApiClient {
  static const productionBaseUrl =
      'https://fitrelay-api.43-155-164-131.sslip.io';

  ApiClient({http.Client? client, String? baseUrl, this.onFallback})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: productionBaseUrl,
          );

  final http.Client _client;
  final String baseUrl;
  final void Function(Object error)? onFallback;

  Future<String> _token() async {
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString('access_token');
    final cachedOrigin = preferences.getString('access_token_origin');
    if (cached != null && cachedOrigin == baseUrl) return cached;
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/installations'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'invite_code': 'EARLY-ACCESS-001',
            'platform': 'android',
            'app_version': '0.1.0',
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 201) {
      throw ApiException('无法初始化客户端', response.statusCode);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = payload['access_token'] as String;
    await preferences.setString('access_token', token);
    await preferences.setString('access_token_origin', baseUrl);
    return token;
  }

  Future<WorkoutPlan> generatePlan(String rawText) async {
    try {
      final token = await _token();
      final preferences = await SharedPreferences.getInstance();
      final profile = _profileContext(preferences);
      final history = await WorkoutHistoryStore().load();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/coach/plans'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'request_id': 'req_${DateTime.now().microsecondsSinceEpoch}',
              'locale': 'zh-CN',
              'timezone': 'Asia/Shanghai',
              'catalog_version': 1,
              'profile': profile,
              'checkin': {
                'raw_text': rawText,
                'available_minutes': _minutesFrom(rawText),
                'energy_level': 3,
                'days_since_last_workout': _daysSinceLastWorkout(history),
                'pain': [],
                'wanted_focus': ['full_body'],
                'avoided_focus': [],
              },
              'muscle_states': [],
              'exercise_capabilities': [],
              'available_exercise_slugs': exerciseNames.keys.toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw ApiException('计划生成失败', response.statusCode);
      }
      final plan = WorkoutPlan.fromEnvelope(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (plan.source != 'ai' && plan.source != 'repaired_ai') {
        throw const ApiException('AI 生成结果未通过安全校验，请重试', 503);
      }
      return plan;
    } catch (error) {
      onFallback?.call(error);
      if (error is ApiException) rethrow;
      throw const ApiException('暂时无法连接 AI 教练，请检查网络后重试', 0);
    }
  }

  Future<Map<String, dynamic>> createSummary({
    required int seconds,
    required int completedSets,
  }) async {
    try {
      final token = await _token();
      final response = await _client.post(
        Uri.parse('$baseUrl/v1/coach/summaries'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'request_id': 'req_${DateTime.now().microsecondsSinceEpoch}',
          'session': {
            'actual_duration_seconds': seconds,
            'completed_sets': completedSets,
            'skipped_items': 0,
            'cardio_minutes': 0,
            'muscle_coverage': {'legs': 80, 'back': 70, 'chest': 60},
          },
          'comparable_history': [],
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (error) {
      onFallback?.call(error);
    }
    return {
      'headline': '一次有效的恢复训练。',
      'factual_message': '本次实际完成 $completedSets 个有效组。',
      'source': 'local_fallback',
    };
  }

  Future<WorkoutPlan> shortenPlan(WorkoutPlan current, int minutes) async {
    try {
      final token = await _token();
      final response = await _client.post(
        Uri.parse('$baseUrl/v1/coach/adjustments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'request_id': 'req_${DateTime.now().microsecondsSinceEpoch}',
          'catalog_version': 1,
          'current_plan': {
            'plan_id': current.id,
            'title': current.title,
            'estimated_minutes': current.estimatedMinutes,
            'exercises': current.exercises
                .map((exercise) => {'exercise_slug': exercise.slug})
                .toList(),
          },
          'completed_item_ids': [],
          'adjustment': {
            'type': 'shorten',
            'remaining_minutes': minutes,
            'raw_text': '临时只剩 $minutes 分钟。',
          },
        }),
      );
      if (response.statusCode == 200) {
        return WorkoutPlan.fromEnvelope(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (error) {
      onFallback?.call(error);
    }
    final fallback = fallbackPlan(minutes);
    return WorkoutPlan(
      id: fallback.id,
      title: '缩短版全身训练',
      goalSummary: fallback.goalSummary,
      coachMessage: '已按剩余 $minutes 分钟重排，保留三个主要动作。',
      estimatedMinutes: minutes,
      source: fallback.source,
      exercises: fallback.exercises.take(minutes <= 20 ? 2 : 3).toList(),
    );
  }

  static int _minutesFrom(String text) {
    final match = RegExp(r'(\d{2,3})\s*分钟').firstMatch(text);
    return int.tryParse(match?.group(1) ?? '')?.clamp(10, 120) ?? 60;
  }

  static Map<String, dynamic> _profileContext(SharedPreferences preferences) {
    final experience = preferences.getString('profile_experience');
    final limitation = preferences.getString('profile_limitation');
    final note = preferences.getString('profile_note') ?? '';
    final profilePreferences = <String>[];
    if (note.contains('器械')) profilePreferences.add('machine_training');
    if (note.contains('有氧')) profilePreferences.add('cardio_after_strength');
    if (note.contains('不喜欢跑步')) profilePreferences.add('avoid_running');
    if (profilePreferences.isEmpty) {
      profilePreferences.add('balanced_full_body');
    }
    return {
      'primary_goal': note.contains('增肌')
          ? 'gradual_muscle_gain'
          : 'maintain_muscle',
      'experience_level': experience == '比较熟悉'
          ? 'experienced'
          : 'some_experience',
      'environment': 'commercial_gym',
      'coaching_tone': 'warm_specific',
      'preferences': profilePreferences,
      'constraints': [if (limitation != null && limitation != '暂无') limitation],
    };
  }

  static int _daysSinceLastWorkout(List<WorkoutRecord> history) {
    if (history.isEmpty) return 30;
    return DateTime.now()
        .difference(history.first.completedAt)
        .inDays
        .clamp(0, 365);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

WorkoutPlan fallbackPlan(int minutes) {
  final exercises = [
    const WorkoutExercise(
      slug: 'leg_press',
      name: '腿举',
      sets: 3,
      repsMin: 10,
      repsMax: 12,
      restSeconds: 90,
      loadKg: 65,
      cue: '腰臀贴紧靠背，膝盖与脚尖方向一致。',
    ),
    const WorkoutExercise(
      slug: 'machine_chest_press',
      name: '器械推胸',
      sets: 3,
      repsMin: 8,
      repsMax: 12,
      restSeconds: 90,
      loadKg: 30,
      cue: '肩胛稳定，不耸肩。',
    ),
    const WorkoutExercise(
      slug: 'lat_pulldown',
      name: '高位下拉',
      sets: 3,
      repsMin: 10,
      repsMax: 12,
      restSeconds: 90,
      loadKg: 40,
      cue: '拉向锁骨附近，避免大幅后仰。',
    ),
    const WorkoutExercise(
      slug: 'machine_leg_curl',
      name: '坐姿腿弯举',
      sets: 2,
      repsMin: 10,
      repsMax: 15,
      restSeconds: 75,
      loadKg: 25,
      cue: '控制回程，不要让配重快速弹回。',
    ),
    const WorkoutExercise(
      slug: 'incline_treadmill_walk',
      name: '跑步机快走',
      sets: 1,
      repsMin: 15,
      repsMax: 15,
      restSeconds: 0,
      loadKg: 5,
      cue: '保持自然步幅和稳定呼吸。',
    ),
  ];
  final exerciseCount = minutes <= 20
      ? 2
      : minutes <= 45
      ? 3
      : exercises.length;
  return WorkoutPlan(
    id: 'local_${DateTime.now().millisecondsSinceEpoch}',
    title: '恢复型全身训练',
    goalSummary: '重新覆盖主要肌群，找回动作节奏。',
    coachMessage: '今天动作稳定优先，每组保留约 3 次余力。',
    estimatedMinutes: exerciseCount == exercises.length && minutes > 68
        ? 68
        : minutes,
    source: 'local_fallback',
    exercises: exercises.take(exerciseCount).toList(),
  );
}
