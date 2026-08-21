import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/resolved_location.dart';
import '../models/weather.dart';
import 'weather_alert_source.dart';
import 'weather_source.dart';
import 'wmo_weather_code.dart';

class WeatherDataFailure implements Exception {
  const WeatherDataFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenMeteoWeatherSource implements WeatherSource {
  OpenMeteoWeatherSource({http.Client? client, WeatherAlertSource? alertSource})
    : _client = client ?? http.Client(),
      _alertSource = alertSource;

  final http.Client _client;
  final WeatherAlertSource? _alertSource;

  @override
  Future<WeatherReport> fetchWeather(ResolvedLocation location) async {
    final forecastFuture = _client
        .get(_forecastUri(location))
        .timeout(const Duration(seconds: 12));
    final airFuture = _fetchAirQuality(location);
    final alertFuture = _fetchAlerts(location);
    final forecast = await forecastFuture;

    if (forecast.statusCode != 200) {
      throw WeatherDataFailure('天气服务返回 ${forecast.statusCode}');
    }

    try {
      final decoded = jsonDecode(forecast.body);
      if (decoded is! Map<String, Object?>) {
        throw const WeatherDataFailure('天气数据格式异常');
      }
      return _parse(location, decoded, await airFuture, await alertFuture);
    } on WeatherDataFailure {
      rethrow;
    } catch (_) {
      throw const WeatherDataFailure('天气数据暂时无法解析');
    }
  }

  Future<Map<String, Object?>> _fetchAirQuality(
    ResolvedLocation location,
  ) async {
    try {
      final response = await _client
          .get(_airQualityUri(location))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const {};
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, Object?> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<List<WeatherAlert>> _fetchAlerts(ResolvedLocation location) async {
    try {
      return await _alertSource?.fetchAlerts(location) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Uri _forecastUri(ResolvedLocation location) {
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toStringAsFixed(2),
      'longitude': location.longitude.toStringAsFixed(2),
      'timezone': 'auto',
      'forecast_days': '10',
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'is_day',
        'precipitation',
        'weather_code',
        'cloud_cover',
        'pressure_msl',
        'wind_speed_10m',
        'wind_direction_10m',
        'wind_gusts_10m',
      ].join(','),
      'hourly': [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'dew_point_2m',
        'precipitation_probability',
        'precipitation',
        'weather_code',
        'visibility',
        'wind_speed_10m',
        'uv_index',
      ].join(','),
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'sunrise',
        'sunset',
        'uv_index_max',
        'precipitation_sum',
        'precipitation_probability_max',
      ].join(','),
    });
  }

  Uri _airQualityUri(ResolvedLocation location) {
    return Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': location.latitude.toStringAsFixed(2),
      'longitude': location.longitude.toStringAsFixed(2),
      'timezone': 'auto',
      'current': 'pm10,pm2_5',
    });
  }

  WeatherReport _parse(
    ResolvedLocation location,
    Map<String, Object?> payload,
    Map<String, Object?> airPayload,
    List<WeatherAlert> alerts,
  ) {
    final current = _requiredMap(payload['current'], '实时天气');
    final hourly = _requiredMap(payload['hourly'], '逐小时天气');
    final daily = _requiredMap(payload['daily'], '每日天气');
    final currentTimeValue = current['time'];
    if (currentTimeValue is! String) {
      throw const WeatherDataFailure('天气更新时间缺失');
    }
    final currentTime = DateTime.parse(currentTimeValue);
    final hourTimes = _strings(hourly['time']);
    var currentHourIndex = hourTimes.lastIndexWhere(
      (value) => !DateTime.parse(value).isAfter(currentTime),
    );
    if (currentHourIndex < 0) currentHourIndex = 0;

    final currentCondition = weatherConditionFromWmoCode(
      _integer(current['weather_code']),
    );
    final dailyItems = _parseDaily(daily);
    if (dailyItems.isEmpty) {
      throw const WeatherDataFailure('每日天气数据缺失');
    }
    final currentDay = dailyItems.first;
    final hourlyItems = _parseHourly(hourly, currentHourIndex);
    final rainChance = hourlyItems.isEmpty ? 0 : hourlyItems.first.rainChance;
    final dewPoints = _numbers(hourly['dew_point_2m']);
    final visibility = _numbers(hourly['visibility']);
    final uvValues = _numbers(hourly['uv_index']);
    final airCurrent = airPayload['current'] as Map<String, Object?>?;
    final airQualityAvailable =
        airCurrent?['pm2_5'] is num && airCurrent?['pm10'] is num;
    final pm25 = _number(airCurrent?['pm2_5']);
    final pm10 = _number(airCurrent?['pm10']);
    final aqi = _chineseAqi(pm25, pm10);
    final windSpeed = _number(current['wind_speed_10m']);
    final windDegrees = _integer(current['wind_direction_10m']);

    return WeatherReport(
      city: location.city,
      district: location.district,
      latitude: location.latitude,
      longitude: location.longitude,
      updatedAt: currentTime,
      temperature: _round(current['temperature_2m']),
      feelsLike: _round(current['apparent_temperature']),
      high: currentDay.high,
      low: currentDay.low,
      condition: currentCondition,
      summary: _summary(currentCondition, rainChance),
      rainChance: rainChance,
      precipitation: _number(current['precipitation']),
      humidity: _integer(current['relative_humidity_2m']),
      dewPoint: currentHourIndex < dewPoints.length
          ? dewPoints[currentHourIndex].round()
          : 0,
      windDirection: _windDirection(windDegrees),
      windDegrees: windDegrees,
      windLevel: _beaufort(windSpeed),
      windSpeed: windSpeed,
      windGust: _number(current['wind_gusts_10m']),
      airQuality: airQualityAvailable ? _airQualityLabel(aqi) : '暂无',
      airQualityIndex: aqi,
      pm25: pm25,
      airQualityAvailable: airQualityAvailable,
      uvIndex: currentHourIndex < uvValues.length
          ? uvValues[currentHourIndex]
          : currentDay.uvIndex,
      visibility: currentHourIndex < visibility.length
          ? visibility[currentHourIndex] / 1000
          : 0,
      pressure: _round(current['pressure_msl']),
      cloudCover: _integer(current['cloud_cover']),
      sunrise: currentDay.sunrise,
      sunset: currentDay.sunset,
      isDay: _integer(current['is_day']) == 1,
      hourly: hourlyItems,
      daily: dailyItems,
      alerts: alerts,
    );
  }

  List<HourForecast> _parseHourly(Map<String, Object?> data, int start) {
    final times = _strings(data['time']);
    final temperatures = _numbers(data['temperature_2m']);
    final apparent = _numbers(data['apparent_temperature']);
    final humidity = _numbers(data['relative_humidity_2m']);
    final chances = _numbers(data['precipitation_probability']);
    final precipitation = _numbers(data['precipitation']);
    final codes = _numbers(data['weather_code']);
    final wind = _numbers(data['wind_speed_10m']);
    final end = [
      times.length,
      temperatures.length,
      apparent.length,
      humidity.length,
      chances.length,
      precipitation.length,
      codes.length,
      wind.length,
      start + 24,
    ].reduce(math.min);

    return [
      for (var index = start; index < end; index++)
        HourForecast(
          time: DateTime.parse(times[index]),
          temperature: temperatures[index].round(),
          feelsLike: apparent[index].round(),
          condition: weatherConditionFromWmoCode(codes[index].round()),
          rainChance: chances[index].round(),
          precipitation: precipitation[index],
          humidity: humidity[index].round(),
          windSpeed: wind[index],
        ),
    ];
  }

  List<DayForecast> _parseDaily(Map<String, Object?> data) {
    final dates = _strings(data['time']);
    final highs = _numbers(data['temperature_2m_max']);
    final lows = _numbers(data['temperature_2m_min']);
    final codes = _numbers(data['weather_code']);
    final chances = _numbers(data['precipitation_probability_max']);
    final precipitation = _numbers(data['precipitation_sum']);
    final uv = _numbers(data['uv_index_max']);
    final sunrise = _strings(data['sunrise']);
    final sunset = _strings(data['sunset']);

    final end = [
      dates.length,
      highs.length,
      lows.length,
      codes.length,
      chances.length,
      precipitation.length,
      uv.length,
      sunrise.length,
      sunset.length,
    ].reduce(math.min);

    return [
      for (var index = 0; index < end; index++)
        DayForecast(
          date: DateTime.parse(dates[index]),
          high: highs[index].round(),
          low: lows[index].round(),
          condition: weatherConditionFromWmoCode(codes[index].round()),
          rainChance: chances[index].round(),
          precipitation: precipitation[index],
          uvIndex: uv[index],
          sunrise: DateTime.parse(sunrise[index]),
          sunset: DateTime.parse(sunset[index]),
        ),
    ];
  }

  String _summary(WeatherCondition condition, int rainChance) {
    if (rainChance >= 70) return '降水可能性较高，天空似乎已经做出了决定，请留意变化。';
    return switch (condition) {
      WeatherCondition.clear => '天空维持晴朗，今天大致会照常进行。',
      WeatherCondition.partlyCloudy => '云层正在按自己的计划移动，晚间总体平稳。',
      WeatherCondition.cloudy => '云层较厚，天气暂时没有别的打算。',
      WeatherCondition.lightRain => '可能有间歇性小雨，降水概率保持谨慎。',
      WeatherCondition.rain => '降雨可能持续一段时间，情况仍在发展。',
      WeatherCondition.heavyRain => '降雨较强，天气这次没有开玩笑，请留意最新预警信息。',
      WeatherCondition.freezingRain => '可能出现冻雨或冻毛毛雨，路面容易结冰，请谨慎出行。',
      WeatherCondition.thunderstorm => '天空的意见比较响亮，可能出现雷电，请减少户外活动。',
      WeatherCondition.snow => '道路正在重新考虑摩擦力；可能有降雪，出行请注意安全。',
      WeatherCondition.fog => '雾气影响能见度，驾车请减速并保持安全距离。',
      WeatherCondition.haze => '远方今天决定低调一些，能见度和空气质量偏低，请做好防护。',
    };
  }

  int _chineseAqi(double pm25, double pm10) {
    return math.max(
      _pollutantAqi(pm25, const [0, 35, 75, 115, 150, 250, 350, 500]),
      _pollutantAqi(pm10, const [0, 50, 150, 250, 350, 420, 500, 600]),
    );
  }

  int _pollutantAqi(double value, List<num> limits) {
    const scores = [0, 50, 100, 150, 200, 300, 400, 500];
    if (value <= 0) return 0;
    for (var index = 0; index < limits.length - 1; index++) {
      if (value <= limits[index + 1]) {
        final ratio =
            (value - limits[index]) / (limits[index + 1] - limits[index]);
        return (scores[index] + ratio * (scores[index + 1] - scores[index]))
            .round();
      }
    }
    return 500;
  }

  String _airQualityLabel(int aqi) {
    if (aqi <= 50) return '优';
    if (aqi <= 100) return '良';
    if (aqi <= 150) return '轻度污染';
    if (aqi <= 200) return '中度污染';
    if (aqi <= 300) return '重度污染';
    return '严重污染';
  }

  int _beaufort(double kmh) {
    const limits = [1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118];
    for (var index = 0; index < limits.length; index++) {
      if (kmh < limits[index]) return index;
    }
    return 12;
  }

  String _windDirection(int degrees) {
    const names = ['北风', '东北风', '东风', '东南风', '南风', '西南风', '西风', '西北风'];
    return names[((degrees + 22.5) ~/ 45) % 8];
  }

  Map<String, Object?> _requiredMap(Object? value, String name) {
    if (value is Map<String, Object?>) return value;
    throw WeatherDataFailure('$name数据缺失');
  }

  List<String> _strings(Object? value) {
    if (value is! List<Object?>) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  List<double> _numbers(Object? value) {
    if (value is! List<Object?>) return const [];
    return value.map(_number).toList(growable: false);
  }

  double _number(Object? value) => value is num ? value.toDouble() : 0;

  int _integer(Object? value) => _number(value).round();

  int _round(Object? value) => _number(value).round();
}
