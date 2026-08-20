import '../models/weather.dart';

class MurphyWeatherAdapter {
  const MurphyWeatherAdapter();

  static const _protectedConditions = {
    WeatherCondition.heavyRain,
    WeatherCondition.thunderstorm,
    WeatherCondition.snow,
    WeatherCondition.haze,
  };

  WeatherReport apply(WeatherReport source) {
    if (source.alerts.isNotEmpty) return source;

    final protectCurrent = _protectCurrent(source);
    final condition = protectCurrent
        ? source.condition
        : _adaptCondition(source.condition);

    return source.copyWith(
      condition: condition,
      summary: protectCurrent ? source.summary : _summaryFor(condition),
      rainChance: protectCurrent
          ? source.rainChance
          : _adaptRainChance(source.rainChance, source.condition),
      hourly: source.hourly
          .map(
            (item) => _protectHour(item)
                ? item
                : item.copyWith(
                    condition: _adaptCondition(item.condition),
                    rainChance: _adaptRainChance(
                      item.rainChance,
                      item.condition,
                    ),
                  ),
          )
          .toList(growable: false),
      daily: source.daily
          .map(
            (item) => _protectDay(item)
                ? item
                : item.copyWith(
                    condition: _adaptCondition(item.condition),
                    rainChance: _adaptRainChance(
                      item.rainChance,
                      item.condition,
                    ),
                  ),
          )
          .toList(growable: false),
    );
  }

  bool _protectCurrent(WeatherReport report) {
    return _protectedConditions.contains(report.condition) ||
        report.rainChance >= 60 ||
        report.precipitation >= 0.5 ||
        report.windGust >= 50 ||
        (report.visibility > 0 && report.visibility < 3) ||
        report.temperature >= 40 ||
        report.temperature <= -15;
  }

  bool _protectHour(HourForecast item) {
    return _protectedConditions.contains(item.condition) ||
        item.rainChance >= 60 ||
        item.precipitation >= 0.5 ||
        item.windSpeed >= 39;
  }

  bool _protectDay(DayForecast item) {
    return _protectedConditions.contains(item.condition) ||
        item.rainChance >= 60 ||
        item.precipitation >= 5;
  }

  WeatherCondition _adaptCondition(WeatherCondition condition) {
    if (_protectedConditions.contains(condition)) return condition;

    return switch (condition) {
      WeatherCondition.clear => WeatherCondition.lightRain,
      WeatherCondition.partlyCloudy => WeatherCondition.rain,
      WeatherCondition.cloudy => WeatherCondition.clear,
      WeatherCondition.lightRain => WeatherCondition.partlyCloudy,
      WeatherCondition.rain => WeatherCondition.clear,
      _ => condition,
    };
  }

  int _adaptRainChance(int chance, WeatherCondition condition) {
    if (_protectedConditions.contains(condition)) return chance;
    final normalized = chance.clamp(0, 100);
    return switch (condition) {
      WeatherCondition.clear || WeatherCondition.partlyCloudy =>
        (55 + (40 - normalized.clamp(0, 40)) * 0.5).round().clamp(55, 75),
      WeatherCondition.cloudy => (normalized * 0.35).round().clamp(5, 35),
      WeatherCondition.lightRain ||
      WeatherCondition.rain => ((100 - normalized) * 0.25).round().clamp(8, 35),
      _ => normalized,
    };
  }

  String _summaryFor(WeatherCondition condition) {
    return switch (condition) {
      WeatherCondition.clear => '天空维持晴朗，今天大致会照常进行。',
      WeatherCondition.partlyCloudy => '云层正在按自己的计划移动，晚间总体平稳。',
      WeatherCondition.cloudy => '云层较厚，天气暂时没有别的打算。',
      WeatherCondition.lightRain => '可能有间歇性小雨，降水概率保持谨慎。',
      WeatherCondition.rain => '降雨可能持续一段时间，情况仍在发展。',
      WeatherCondition.heavyRain => '降雨较强，天气这次没有开玩笑，请留意最新预警信息。',
      WeatherCondition.thunderstorm => '天空的意见比较响亮，可能出现雷电，请减少户外活动。',
      WeatherCondition.snow => '道路正在重新考虑摩擦力；有降雪，出行请注意安全。',
      WeatherCondition.haze => '远方今天决定低调一些，能见度和空气质量偏低，请做好防护。',
    };
  }
}
