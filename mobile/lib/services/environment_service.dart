import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EnvironmentSnapshot {
  const EnvironmentSnapshot({
    required this.locationLabel,
    required this.weatherLabel,
    required this.humidity,
    required this.updatedAt,
  });

  final String locationLabel;
  final String weatherLabel;
  final int humidity;
  final DateTime updatedAt;

  String get humidityLabel => '湿度 $humidity%';
}

abstract interface class EnvironmentService {
  Future<EnvironmentSnapshot?> cached();

  Future<EnvironmentSnapshot> refresh();
}

class LiveEnvironmentService implements EnvironmentService {
  LiveEnvironmentService({http.Client? client})
    : _client = client ?? http.Client();

  static const _locationKey = 'environment_location';
  static const _weatherKey = 'environment_weather';
  static const _humidityKey = 'environment_humidity';
  static const _updatedAtKey = 'environment_updated_at_ms';

  final http.Client _client;

  @override
  Future<EnvironmentSnapshot?> cached() async {
    final preferences = await SharedPreferences.getInstance();
    final location = preferences.getString(_locationKey);
    final weather = preferences.getString(_weatherKey);
    final humidity = preferences.getInt(_humidityKey);
    final updatedAt = preferences.getInt(_updatedAtKey);
    if (location == null ||
        weather == null ||
        humidity == null ||
        updatedAt == null) {
      return null;
    }
    return EnvironmentSnapshot(
      locationLabel: location,
      weatherLabel: weather,
      humidity: humidity,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  @override
  Future<EnvironmentSnapshot> refresh() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const EnvironmentException('请先开启系统定位');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const EnvironmentException('未获得定位权限');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const EnvironmentException('定位权限已关闭，请在系统设置中开启');
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw const EnvironmentException('暂时无法取得当前位置');
    }

    final results = await Future.wait<Object>([
      _locationLabel(position.latitude, position.longitude),
      _weather(position.latitude, position.longitude),
    ]);
    final weather = results[1] as _WeatherNow;
    final snapshot = EnvironmentSnapshot(
      locationLabel: results[0] as String,
      weatherLabel: '${weather.description} ${weather.temperature.round()}°',
      humidity: weather.humidity.round(),
      updatedAt: DateTime.now(),
    );
    await _cache(snapshot);
    return snapshot;
  }

  Future<String> _locationLabel(double latitude, double longitude) async {
    try {
      final placemarks = await Geocoding(
        locale: const Locale('zh', 'CN'),
      ).placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _coordinateLabel(latitude, longitude);
      final place = placemarks.first;
      final city = _firstNonEmpty([place.locality, place.administrativeArea]);
      final district = _firstNonEmpty([
        place.subLocality,
        place.subAdministrativeArea,
      ]);
      final parts = <String>[];
      if (city != null) parts.add(city);
      if (district != null && district != city) parts.add(district);
      return parts.isEmpty
          ? _coordinateLabel(latitude, longitude)
          : parts.join(' · ');
    } on Exception {
      return _coordinateLabel(latitude, longitude);
    }
  }

  Future<_WeatherNow> _weather(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
      'current': 'temperature_2m,relative_humidity_2m,weather_code',
      'timezone': 'auto',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw EnvironmentException('天气服务暂时不可用 (${response.statusCode})');
    }
    return _WeatherNow.fromOpenMeteo(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> _cache(EnvironmentSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_locationKey, snapshot.locationLabel),
      preferences.setString(_weatherKey, snapshot.weatherLabel),
      preferences.setInt(_humidityKey, snapshot.humidity),
      preferences.setInt(
        _updatedAtKey,
        snapshot.updatedAt.millisecondsSinceEpoch,
      ),
    ]);
  }

  static String? _firstNonEmpty(Iterable<String?> candidates) {
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _coordinateLabel(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(2)}°, ${longitude.toStringAsFixed(2)}°';
}

class EnvironmentException implements Exception {
  const EnvironmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _WeatherNow {
  const _WeatherNow({
    required this.temperature,
    required this.humidity,
    required this.description,
  });

  final double temperature;
  final double humidity;
  final String description;

  factory _WeatherNow.fromOpenMeteo(Map<String, dynamic> payload) {
    final current = payload['current'] as Map<String, dynamic>?;
    final temperature = current?['temperature_2m'] as num?;
    final humidity = current?['relative_humidity_2m'] as num?;
    final code = current?['weather_code'] as num?;
    if (temperature == null || humidity == null || code == null) {
      throw const EnvironmentException('天气数据格式异常');
    }
    return _WeatherNow(
      temperature: temperature.toDouble(),
      humidity: humidity.toDouble(),
      description: _weatherDescription(code.toInt()),
    );
  }
}

String _weatherDescription(int code) {
  if (code == 0) return '晴';
  if (code <= 3) return '多云';
  if (code == 45 || code == 48) return '有雾';
  if (code >= 51 && code <= 57) return '细雨';
  if (code >= 61 && code <= 67) return '有雨';
  if (code >= 71 && code <= 77) return '有雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 85 && code <= 86) return '阵雪';
  if (code >= 95) return '雷雨';
  return '天气';
}
