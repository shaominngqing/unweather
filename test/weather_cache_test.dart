import 'package:flutter_test/flutter_test.dart';
import 'package:murphy/models/resolved_location.dart';
import 'package:murphy/services/weather_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_weather.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps separate weather entries and selects the nearest one', () async {
    final cache = WeatherCache();
    final guangzhou = testWeather();
    final beijing = testWeather(
      city: '北京市',
      district: '东城区',
      latitude: 39.90,
      longitude: 116.41,
    );

    await cache.write(guangzhou);
    await cache.write(beijing);

    final last = await cache.readLast();
    final nearby = await cache.readNearby(
      const ResolvedLocation(
        latitude: 23.12,
        longitude: 113.27,
        city: '广州市',
        district: '越秀区',
      ),
    );

    expect(last?.report.city, '北京市');
    expect(last?.report.isCached, isTrue);
    expect(nearby?.report.city, '广州市');
    expect(nearby?.report.isCached, isTrue);
  });
}
