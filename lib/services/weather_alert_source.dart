import '../models/resolved_location.dart';
import '../models/weather.dart';

abstract interface class WeatherAlertSource {
  Future<List<WeatherAlert>> fetchAlerts(ResolvedLocation location);
}
