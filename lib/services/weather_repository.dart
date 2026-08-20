import '../models/resolved_location.dart';
import '../models/weather.dart';
import 'location_service.dart';
import 'murphy_weather_adapter.dart';
import 'weather_cache.dart';
import 'weather_source.dart';

abstract interface class WeatherRepositoryContract {
  Future<WeatherReport?> loadCachedWeather();

  Future<WeatherReport> fetchCurrentLocation();

  Future<WeatherReport> searchCity(String query);

  Future<List<ResolvedLocation>> searchLocations(String query);

  Future<WeatherReport> fetchLocation(ResolvedLocation location);

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class WeatherRepository implements WeatherRepositoryContract {
  WeatherRepository({
    required LocationService locationService,
    required WeatherSource source,
    required MurphyWeatherAdapter adapter,
    required WeatherCache cache,
  }) : _locationService = locationService,
       _source = source,
       _adapter = adapter,
       _cache = cache;

  final LocationService _locationService;
  final WeatherSource _source;
  final MurphyWeatherAdapter _adapter;
  final WeatherCache _cache;

  @override
  Future<WeatherReport?> loadCachedWeather() async {
    final cached = await _cache.readLast();
    if (cached == null || !_isFresh(cached, const Duration(hours: 24))) {
      return null;
    }
    return cached.report;
  }

  @override
  Future<WeatherReport> fetchCurrentLocation() async {
    final location = await _locationService.currentLocation();
    return fetchLocation(location);
  }

  @override
  Future<WeatherReport> searchCity(String query) async {
    final location = await _locationService.search(query);
    return fetchLocation(location);
  }

  @override
  Future<List<ResolvedLocation>> searchLocations(String query) =>
      _locationService.searchCandidates(query);

  @override
  Future<WeatherReport> fetchLocation(ResolvedLocation location) async {
    try {
      final source = await _source.fetchWeather(location);
      final report = _adapter.apply(source);
      await _cache.write(report);
      return report;
    } catch (_) {
      final cached = await _cache.readNearby(location);
      if (cached != null && _isFresh(cached, const Duration(hours: 6))) {
        return cached.report;
      }
      rethrow;
    }
  }

  bool _isFresh(CachedWeather cached, Duration maximumAge) {
    final age = DateTime.now().toUtc().difference(cached.cachedAt).abs();
    return age <= maximumAge;
  }

  @override
  Future<bool> openAppSettings() => _locationService.openAppSettings();

  @override
  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();
}
