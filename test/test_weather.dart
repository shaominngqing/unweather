import 'package:murphy/models/weather.dart';
import 'package:murphy/models/resolved_location.dart';
import 'package:murphy/services/weather_repository.dart';

WeatherReport testWeather({
  WeatherCondition condition = WeatherCondition.partlyCloudy,
  List<WeatherAlert> alerts = const [],
  String city = '广州市',
  String district = '天河区',
  double latitude = 23.13,
  double longitude = 113.26,
  int rainChance = 12,
  double precipitation = 0,
  double windGust = 18,
  bool airQualityAvailable = true,
}) {
  final now = DateTime(2026, 8, 20, 14);
  return WeatherReport(
    city: city,
    district: district,
    latitude: latitude,
    longitude: longitude,
    updatedAt: now,
    temperature: 31,
    feelsLike: 34,
    high: 34,
    low: 27,
    condition: condition,
    summary: '天气平稳',
    rainChance: rainChance,
    precipitation: precipitation,
    humidity: 70,
    dewPoint: 24,
    windDirection: '东南风',
    windDegrees: 135,
    windLevel: 2,
    windSpeed: 9,
    windGust: windGust,
    airQuality: '优',
    airQualityIndex: 38,
    pm25: 18,
    airQualityAvailable: airQualityAvailable,
    uvIndex: 4,
    visibility: 12,
    pressure: 1008,
    cloudCover: 38,
    sunrise: DateTime(2026, 8, 20, 6, 3),
    sunset: DateTime(2026, 8, 20, 18, 52),
    isDay: true,
    hourly: [
      for (var index = 0; index < 24; index++)
        HourForecast(
          time: now.add(Duration(hours: index)),
          temperature: 31 + (index % 3),
          feelsLike: 34,
          condition: condition,
          rainChance: rainChance,
          precipitation: precipitation,
          humidity: 70,
          windSpeed: 9,
        ),
    ],
    daily: [
      for (var index = 0; index < 10; index++)
        DayForecast(
          date: DateTime(2026, 8, 20 + index),
          high: 34 - (index % 3),
          low: 27 - (index % 2),
          condition: condition,
          rainChance: rainChance,
          precipitation: precipitation,
          uvIndex: 6,
          sunrise: DateTime(2026, 8, 20 + index, 6, 3),
          sunset: DateTime(2026, 8, 20 + index, 18, 52),
        ),
    ],
    alerts: alerts,
  );
}

class FakeWeatherRepository implements WeatherRepositoryContract {
  FakeWeatherRepository(this.report);

  final WeatherReport report;

  @override
  Future<WeatherReport?> loadCachedWeather() async => null;

  @override
  Future<WeatherReport> fetchCurrentLocation() async => report;

  @override
  Future<WeatherReport> searchCity(String query) async => report;

  @override
  Future<List<ResolvedLocation>> searchLocations(String query) async => [
    ResolvedLocation(
      latitude: report.latitude,
      longitude: report.longitude,
      city: report.city,
      district: report.district,
    ),
  ];

  @override
  Future<WeatherReport> fetchLocation(ResolvedLocation location) async =>
      report;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
