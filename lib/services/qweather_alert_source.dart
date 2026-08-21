import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/resolved_location.dart';
import '../models/weather.dart';
import 'weather_alert_source.dart';

/// Loads official weather alerts from QWeather when build-time credentials
/// are provided. Without credentials it safely returns no alerts.
class QWeatherAlertSource implements WeatherAlertSource {
  QWeatherAlertSource({
    http.Client? client,
    String? apiHost,
    String? iosApiKey,
    String? androidApiKey,
    String? iosBundleId,
    String? androidPackageName,
    String? androidCertificateSha1,
    QWeatherPlatform? platform,
  }) : _client = client ?? http.Client(),
       _apiHost = apiHost ?? const String.fromEnvironment('QWEATHER_API_HOST'),
       _iosApiKey =
           iosApiKey ?? const String.fromEnvironment('QWEATHER_IOS_API_KEY'),
       _androidApiKey =
           androidApiKey ??
           const String.fromEnvironment('QWEATHER_ANDROID_API_KEY'),
       _iosBundleId =
           iosBundleId ??
           const String.fromEnvironment(
             'QWEATHER_IOS_BUNDLE_ID',
             defaultValue: 'com.murphyweather.murphy',
           ),
       _androidPackageName =
           androidPackageName ??
           const String.fromEnvironment(
             'QWEATHER_ANDROID_PACKAGE_NAME',
             defaultValue: 'com.murphyweather.murphy',
           ),
       _androidCertificateSha1 =
           androidCertificateSha1 ??
           const String.fromEnvironment(
             'QWEATHER_ANDROID_CERT_SHA1',
             defaultValue:
                 'F3:60:3F:73:2A:F2:3A:BC:BE:1C:DB:F6:F4:5B:FD:5E:34:8C:01:E9',
           ),
       _platform = platform ?? _currentPlatform();

  final http.Client _client;
  final String _apiHost;
  final String _iosApiKey;
  final String _androidApiKey;
  final String _iosBundleId;
  final String _androidPackageName;
  final String _androidCertificateSha1;
  final QWeatherPlatform _platform;

  bool get isConfigured => _apiHost.isNotEmpty && _apiKey.isNotEmpty;

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
            'X-QW-Api-Key': _apiKey,
            ..._appRestrictionHeaders,
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

  String get _apiKey => switch (_platform) {
    QWeatherPlatform.iOS => _iosApiKey.trim(),
    QWeatherPlatform.android => _androidApiKey.trim(),
    QWeatherPlatform.unsupported => '',
  };

  Map<String, String> get _appRestrictionHeaders => switch (_platform) {
    QWeatherPlatform.iOS => {'X-iOS-Bundle-Id': _iosBundleId.trim()},
    QWeatherPlatform.android => {
      'X-Android-Package-Name': _androidPackageName.trim(),
      'X-Android-Cert': _androidCertificateSha1.trim(),
    },
    QWeatherPlatform.unsupported => const {},
  };

  static QWeatherPlatform _currentPlatform() {
    if (Platform.isIOS) return QWeatherPlatform.iOS;
    if (Platform.isAndroid) return QWeatherPlatform.android;
    return QWeatherPlatform.unsupported;
  }

  String _string(Object? value) => value is String ? value.trim() : '';
}

enum QWeatherPlatform { iOS, android, unsupported }
