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
      return http.Response(
        jsonEncode({
          'result_type': 'workout_plan',
          'request_id': 'req_test',
          'source': 'deterministic_fallback',
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
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('access_token'), isNotNull);
  });
}
