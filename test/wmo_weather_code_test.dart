import 'package:flutter_test/flutter_test.dart';
import 'package:murphy/models/weather.dart';
import 'package:murphy/services/wmo_weather_code.dart';

void main() {
  test('maps every supported WMO weather code to the correct condition', () {
    const expected = <WeatherCondition, List<int>>{
      WeatherCondition.clear: [0],
      WeatherCondition.partlyCloudy: [1, 2],
      WeatherCondition.cloudy: [3],
      WeatherCondition.fog: [45, 48],
      WeatherCondition.lightRain: [51, 53, 55, 61, 80],
      WeatherCondition.freezingRain: [56, 57, 66, 67],
      WeatherCondition.rain: [63, 81],
      WeatherCondition.heavyRain: [65, 82],
      WeatherCondition.snow: [71, 73, 75, 77, 85, 86],
      WeatherCondition.thunderstorm: [95, 96, 99],
    };

    for (final entry in expected.entries) {
      for (final code in entry.value) {
        expect(
          weatherConditionFromWmoCode(code),
          entry.key,
          reason: 'WMO code $code',
        );
      }
    }
  });

  test('falls back to cloudy for an unknown WMO code', () {
    expect(weatherConditionFromWmoCode(999), WeatherCondition.cloudy);
  });
}
