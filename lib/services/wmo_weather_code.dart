import '../models/weather.dart';

WeatherCondition weatherConditionFromWmoCode(int code) {
  return switch (code) {
    0 => WeatherCondition.clear,
    1 || 2 => WeatherCondition.partlyCloudy,
    3 => WeatherCondition.cloudy,
    45 || 48 => WeatherCondition.fog,
    51 || 53 || 55 || 61 || 80 => WeatherCondition.lightRain,
    56 || 57 || 66 || 67 => WeatherCondition.freezingRain,
    63 || 81 => WeatherCondition.rain,
    65 || 82 => WeatherCondition.heavyRain,
    71 || 73 || 75 || 77 || 85 || 86 => WeatherCondition.snow,
    95 || 96 || 99 => WeatherCondition.thunderstorm,
    _ => WeatherCondition.cloudy,
  };
}
