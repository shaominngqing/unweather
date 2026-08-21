import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:murphy/models/resolved_location.dart';
import 'package:murphy/services/qweather_alert_source.dart';

void main() {
  const location = ResolvedLocation(
    latitude: 31.2304,
    longitude: 121.4737,
    city: '上海市',
    district: '黄浦区',
  );

  test('uses the iOS API key and bundle restriction header', () async {
    late http.Request captured;
    final source = QWeatherAlertSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          _activeAlertResponse,
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      apiHost: 'example.qweatherapi.com',
      iosApiKey: 'ios-secret',
      androidApiKey: 'android-secret',
      iosBundleId: 'com.example.ios',
      platform: QWeatherPlatform.iOS,
    );

    final alerts = await source.fetchAlerts(location);

    expect(captured.headers['X-QW-Api-Key'], 'ios-secret');
    expect(captured.headers['X-iOS-Bundle-Id'], 'com.example.ios');
    expect(captured.headers, isNot(contains('X-QW-iOS-Bundle-Id')));
    expect(captured.headers, isNot(contains('X-Android-Package-Name')));
    expect(captured.url.host, 'example.qweatherapi.com');
    expect(captured.url.path, '/weatheralert/v1/current/31.23/121.47');
    expect(alerts, hasLength(1));
    expect(alerts.single.title, '上海市高温黄色预警');
    expect(alerts.single.level, 'Yellow');
  });

  test('uses the Android API key and app restriction headers', () async {
    late http.Request captured;
    final source = QWeatherAlertSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"alerts": []}', 200);
      }),
      apiHost: 'https://example.qweatherapi.com/',
      iosApiKey: 'ios-secret',
      androidApiKey: 'android-secret',
      androidPackageName: 'com.example.android',
      androidCertificateSha1: 'AA:BB:CC',
      platform: QWeatherPlatform.android,
    );

    await source.fetchAlerts(location);

    expect(captured.headers['X-QW-Api-Key'], 'android-secret');
    expect(captured.headers['X-Android-Package-Name'], 'com.example.android');
    expect(captured.headers['X-Android-Cert'], 'AA:BB:CC');
    expect(captured.headers, isNot(contains('Authorization')));
  });

  test('does not request alerts without the current platform key', () async {
    var requested = false;
    final source = QWeatherAlertSource(
      client: MockClient((request) async {
        requested = true;
        return http.Response('{"alerts": []}', 200);
      }),
      apiHost: 'example.qweatherapi.com',
      iosApiKey: 'ios-secret',
      platform: QWeatherPlatform.android,
    );

    expect(await source.fetchAlerts(location), isEmpty);
    expect(requested, isFalse);
  });
}

const _activeAlertResponse = '''
{
  "alerts": [
    {
      "headline": "上海市高温黄色预警",
      "eventType": {"name": "高温"},
      "color": {"code": "Yellow"},
      "severity": "Moderate",
      "description": "预计今天最高气温较高。",
      "instruction": "减少户外活动。",
      "messageType": {"code": "alert"}
    },
    {
      "headline": "已解除的预警",
      "messageType": {"code": "cancel"}
    }
  ]
}
''';
