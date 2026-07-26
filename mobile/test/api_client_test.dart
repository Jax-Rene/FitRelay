import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suilian_ai/services/api_client.dart';

void main() {
  test('installs, authenticates and parses a server generated plan', () async {
    SharedPreferences.setMockInitialValues({});
    var installationCalled = false;
    var authorizationSeen = false;
    Object? fallbackError;
    Map<String, dynamic>? planRequest;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/installations') {
        installationCalled = true;
        return http.Response(
          jsonEncode({
            'installation_id': 'ins_test',
            'access_token': 'abcdefghijklmnopqrstuvwxyz1234567890',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      authorizationSeen = request.headers.values.any(
        (value) => value.startsWith('Bearer '),
      );
      planRequest = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'result_type': 'workout_plan',
          'request_id': 'req_test',
          'source': 'ai',
          'plan': {
            'plan_id': 'plan_test',
            'title': '恢复型全身训练',
            'goal_summary': '找回节奏',
            'coach_message': '动作稳定优先',
            'estimated_minutes': 40,
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
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final plan = await ApiClient(
      client: client,
      baseUrl: 'http://api.test',
      onFallback: (error) => fallbackError = error,
    ).generatePlan('今天 40 分钟');

    expect(installationCalled, isTrue);
    expect(authorizationSeen, isTrue);
    expect(fallbackError, isNull);
    expect(plan.estimatedMinutes, 40);
    expect(plan.exercises.single.name, '腿举');
    expect(
      (planRequest?['checkin']
          as Map<String, dynamic>)['days_since_last_workout'],
      30,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('access_token'), isNotNull);
  });

  test('uses saved onboarding context in plan requests', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'abcdefghijklmnopqrstuvwxyz1234567890',
      'access_token_origin': 'http://api.test',
      'profile_experience': '比较熟悉',
      'profile_limitation': '膝盖',
      'profile_note': '想增肌，偏好器械，不喜欢跑步。',
    });
    Map<String, dynamic>? planRequest;
    final client = MockClient((request) async {
      planRequest = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'result_type': 'workout_plan',
          'request_id': 'req_profile',
          'source': 'repaired_ai',
          'plan': {
            'plan_id': 'plan_profile',
            'title': '个性化训练',
            'goal_summary': '安全完成训练',
            'coach_message': '动作稳定优先',
            'estimated_minutes': 30,
            'exercises': [
              {
                'exercise_slug': 'leg_press',
                'sets': 2,
                'reps_min': 10,
                'reps_max': 12,
                'rest_seconds': 90,
                'suggested_load_kg': 50,
                'cue': '保持稳定',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await ApiClient(
      client: client,
      baseUrl: 'http://api.test',
    ).generatePlan('今天 30 分钟');

    final profile = planRequest?['profile'] as Map<String, dynamic>;
    expect(profile['primary_goal'], 'gradual_muscle_gain');
    expect(profile['experience_level'], 'experienced');
    expect(profile['constraints'], contains('膝盖'));
    expect(
      profile['preferences'],
      containsAll(['machine_training', 'avoid_running']),
    );
  });

  test(
    'rejects a deterministic server fallback instead of hiding it',
    () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'abcdefghijklmnopqrstuvwxyz1234567890',
        'access_token_origin': 'https://api.test',
      });
      Object? reportedError;
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'result_type': 'workout_plan',
            'request_id': 'req_fallback',
            'source': 'deterministic_fallback',
            'plan': {
              'plan_id': 'plan_fallback',
              'title': '固定计划',
              'goal_summary': '固定内容',
              'coach_message': '固定内容',
              'estimated_minutes': 30,
              'exercises': [
                {
                  'exercise_slug': 'leg_press',
                  'sets': 3,
                  'reps_min': 10,
                  'reps_max': 12,
                  'rest_seconds': 90,
                  'cue': '保持稳定',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await expectLater(
        ApiClient(
          client: client,
          baseUrl: 'https://api.test',
          onFallback: (error) => reportedError = error,
        ).generatePlan('今天 30 分钟'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('未通过安全校验'),
          ),
        ),
      );
      expect(reportedError, isA<ApiException>());
    },
  );
}
