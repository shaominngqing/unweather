import 'package:flutter_test/flutter_test.dart';
import 'package:murphy/models/weather.dart';
import 'package:murphy/services/murphy_weather_adapter.dart';

import 'test_weather.dart';

void main() {
  const adapter = MurphyWeatherAdapter();

  test('adapts ordinary conditions while preserving measurements', () {
    final source = testWeather(condition: WeatherCondition.clear);
    final result = adapter.apply(source);

    expect(result.condition, WeatherCondition.lightRain);
    expect(result.temperature, source.temperature);
    expect(result.feelsLike, source.feelsLike);
    expect(result.humidity, source.humidity);
    expect(result.pressure, source.pressure);
    expect(result.rainChance, inInclusiveRange(55, 75));
    expect(result.hourly.first.rainChance, inInclusiveRange(55, 75));
  });

  test('does not adapt hazardous conditions or alerts', () {
    final source = testWeather(
      condition: WeatherCondition.thunderstorm,
      alerts: const [WeatherAlert(title: '雷电黄色预警', level: '黄色')],
    );
    final result = adapter.apply(source);

    expect(result.condition, WeatherCondition.thunderstorm);
    expect(result.hourly.first.condition, WeatherCondition.thunderstorm);
    expect(result.hourly.first.rainChance, 12);
    expect(result.alerts, same(source.alerts));
  });

  test('preserves numerically hazardous rain without an alert', () {
    final source = testWeather(
      condition: WeatherCondition.rain,
      rainChance: 80,
      precipitation: 3,
    );
    final result = adapter.apply(source);

    expect(result.condition, WeatherCondition.rain);
    expect(result.rainChance, 80);
    expect(result.hourly.first.condition, WeatherCondition.rain);
    expect(result.hourly.first.rainChance, 80);
  });

  test('never adapts freezing rain or fog', () {
    for (final condition in const [
      WeatherCondition.freezingRain,
      WeatherCondition.fog,
    ]) {
      final source = testWeather(condition: condition);
      final result = adapter.apply(source);

      expect(result.condition, condition);
      expect(result.hourly.first.condition, condition);
      expect(result.daily.first.condition, condition);
    }
  });

  test('weather report survives cache serialization', () {
    final report = testWeather();
    final restored = WeatherReport.fromJson(report.toJson());

    expect(restored.city, report.city);
    expect(restored.latitude, report.latitude);
    expect(restored.hourly.length, 24);
    expect(restored.daily.length, 10);
    expect(restored.sunset, report.sunset);
  });
}
