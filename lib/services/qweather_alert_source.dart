import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/resolved_location.dart';
import '../models/weather.dart';
import 'weather_alert_source.dart';

/// Loads official weather alerts from QWeather when build-time credentials
/// are provided. Without credentials it safely returns no alerts.
class QWeatherAlertSource implements WeatherAlertSource {
  QWeatherAlertSource({http.Client? client, String? apiHost, String? token})
    : _client = client ?? http.Client(),
      _apiHost = apiHost ?? const String.fromEnvironment('QWEATHER_API_HOST'),
      _token = token ?? const String.fromEnvironment('QWEATHER_TOKEN');

  final http.Client _client;
  final String _apiHost;
  final String _token;

  bool get isConfigured => _apiHost.isNotEmpty && _token.isNotEmpty;

  @override
  Future<List<WeatherAlert>> fetchAlerts(ResolvedLocation location) async {
    if (!isConfigured) return const [];

    final host = _apiHost
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.https(
      host,
      '/weatheralert/v1/current/'
      '${location.latitude.toStringAsFixed(2)}/'
      '${location.longitude.toStringAsFixed(2)}',
      const {'localTime': 'true', 'lang': 'zh'},
    );
    final response = await _client
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
            'Accept-Encoding': 'gzip',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return const [];

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, Object?>) return const [];
    final rawAlerts = payload['alerts'];
    if (rawAlerts is! List<Object?>) return const [];

    return rawAlerts
        .whereType<Map<String, Object?>>()
        .where((item) => _messageCode(item) != 'cancel')
        .map(_parseAlert)
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
  }

  WeatherAlert _parseAlert(Map<String, Object?> json) {
    final event = json['eventType'] as Map<String, Object?>?;
    final color = json['color'] as Map<String, Object?>?;
    final headline = _string(json['headline']);
    final eventName = _string(event?['name']);
    final colorCode = _string(color?['code']);
    final severity = _string(json['severity']);
    return WeatherAlert(
      title: headline.isNotEmpty ? headline : eventName,
      level: colorCode.isNotEmpty ? colorCode : severity,
      description: _string(json['description']),
      instruction: _string(json['instruction']),
      source: '和风天气 · 官方气象预警',
    );
  }

  String _messageCode(Map<String, Object?> json) {
    final messageType = json['messageType'] as Map<String, Object?>?;
    return _string(messageType?['code']);
  }

  String _string(Object? value) => value is String ? value.trim() : '';
}
