import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/resolved_location.dart';

enum LocationFailureKind {
  servicesDisabled,
  denied,
  deniedForever,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.kind, this.message);

  final LocationFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  LocationService() : _geocoding = Geocoding(locale: const Locale('zh', 'CN'));

  final Geocoding _geocoding;

  Future<ResolvedLocation> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        LocationFailureKind.servicesDisabled,
        '定位服务尚未开启',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(LocationFailureKind.denied, '没有获得定位权限');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureKind.deniedForever,
        '定位权限已关闭，请前往系统设置开启',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return resolve(position.latitude, position.longitude);
    } on LocationFailure {
      rethrow;
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return resolve(last.latitude, last.longitude);
      throw const LocationFailure(
        LocationFailureKind.unavailable,
        '暂时无法取得当前位置',
      );
    }
  }

  Future<ResolvedLocation> search(String query) async {
    final results = await searchCandidates(query);
    return results.first;
  }

  Future<List<ResolvedLocation>> searchCandidates(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const LocationFailure(LocationFailureKind.unavailable, '请输入城市名称');
    }

    try {
      final locations = await _geocoding.locationFromAddress(trimmed);
      if (locations.isEmpty) throw StateError('empty geocoding result');
      final resolved = await Future.wait(
        locations
            .take(6)
            .map((location) => resolve(location.latitude, location.longitude)),
      );
      final unique = <ResolvedLocation>[];
      for (final candidate in resolved) {
        final duplicate = unique.any(
          (item) =>
              (item.latitude - candidate.latitude).abs() < 0.02 &&
              (item.longitude - candidate.longitude).abs() < 0.02,
        );
        if (!duplicate) unique.add(candidate);
      }
      if (unique.isEmpty) throw StateError('empty resolved result');
      return unique;
    } catch (_) {
      throw const LocationFailure(LocationFailureKind.unavailable, '没有找到这个城市');
    }
  }

  Future<ResolvedLocation> resolve(double latitude, double longitude) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      final place = placemarks.first;
      final city = _firstNonEmpty([
        place.locality,
        place.administrativeArea,
        place.subAdministrativeArea,
      ]);
      final district = _firstNonEmpty([
        place.subAdministrativeArea,
        place.subLocality,
        place.name,
      ]);
      return ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        city: city.isEmpty ? '当前位置' : city,
        district: district.isEmpty || district == city ? '当前位置' : district,
      );
    } catch (_) {
      return ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        city: '当前位置',
        district:
            '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}',
      );
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  String _firstNonEmpty(List<String?> values) {
    return values
        .map((value) => value?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  }
}
