import '../models/resolved_location.dart';
import '../models/weather.dart';

abstract interface class WeatherSource {
  Future<WeatherReport> fetchWeather(ResolvedLocation location);
}
