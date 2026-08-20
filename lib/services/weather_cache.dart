import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/resolved_location.dart';
import '../models/weather.dart';

class CachedWeather {
  const CachedWeather({required this.report, required this.cachedAt});

  final WeatherReport report;
  final DateTime cachedAt;
}

class WeatherCache {
  static const _entriesKey = 'murphy.weather.entries.v3';
  static const _legacyKey = 'murphy.last_weather.v2';
  static const _maximumEntries = 8;

  Future<void> write(WeatherReport report) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = await _readEntries(preferences);
    entries.removeWhere(
      (entry) =>
          _distanceKm(
            entry.report.latitude,
            entry.report.longitude,
            report.latitude,
            report.longitude,
          ) <
          5,
    );
    entries.insert(
      0,
      CachedWeather(
        report: report.copyWith(isCached: false),
        cachedAt: DateTime.now().toUtc(),
      ),
    );
    if (entries.length > _maximumEntries) {
      entries.removeRange(_maximumEntries, entries.length);
    }
    await preferences.setString(
      _entriesKey,
      jsonEncode(entries.map(_entryToJson).toList(growable: false)),
    );
  }

  Future<CachedWeather?> readLast() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = await _readEntries(preferences);
    return entries.isEmpty ? null : _asCached(entries.first);
  }

  Future<CachedWeather?> readNearby(
    ResolvedLocation location, {
    double maximumDistanceKm = 20,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = await _readEntries(preferences);
    CachedWeather? nearest;
    var nearestDistance = double.infinity;
    for (final entry in entries) {
      final distance = _distanceKm(
        entry.report.latitude,
        entry.report.longitude,
        location.latitude,
        location.longitude,
      );
      if (distance <= maximumDistanceKm && distance < nearestDistance) {
        nearest = entry;
        nearestDistance = distance;
      }
    }
    return nearest == null ? null : _asCached(nearest);
  }

  Future<List<CachedWeather>> _readEntries(
    SharedPreferences preferences,
  ) async {
    try {
      final encoded = preferences.getString(_entriesKey);
      if (encoded != null) {
        final decoded = jsonDecode(encoded);
        if (decoded is List<Object?>) {
          return decoded
              .whereType<Map<String, Object?>>()
              .map(_entryFromJson)
              .whereType<CachedWeather>()
              .toList(growable: true);
        }
      }

      final legacy = preferences.getString(_legacyKey);
      if (legacy == null) return [];
      final decodedLegacy = jsonDecode(legacy);
      if (decodedLegacy is! Map<String, Object?>) return [];
      final report = WeatherReport.fromJson(decodedLegacy);
      return [
        CachedWeather(report: report, cachedAt: report.updatedAt.toUtc()),
      ];
    } catch (_) {
      return [];
    }
  }

  CachedWeather? _entryFromJson(Map<String, Object?> json) {
    try {
      final reportJson = json['report'];
      final cachedAt = json['cachedAt'];
      if (reportJson is! Map<String, Object?> || cachedAt is! String) {
        return null;
      }
      return CachedWeather(
        report: WeatherReport.fromJson(reportJson),
        cachedAt: DateTime.parse(cachedAt).toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _entryToJson(CachedWeather entry) => {
    'cachedAt': entry.cachedAt.toUtc().toIso8601String(),
    'report': entry.report.toJson(),
  };

  CachedWeather _asCached(CachedWeather entry) => CachedWeather(
    report: entry.report.copyWith(isCached: true),
    cachedAt: entry.cachedAt,
  );

  double _distanceKm(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusKm = 6371.0;
    final latA = latitudeA * math.pi / 180;
    final latB = latitudeB * math.pi / 180;
    final deltaLat = (latitudeB - latitudeA) * math.pi / 180;
    final deltaLon = (longitudeB - longitudeA) * math.pi / 180;
    final haversine =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(latA) *
            math.cos(latB) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return earthRadiusKm *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }
}
