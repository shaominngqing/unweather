enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  lightRain,
  rain,
  heavyRain,
  freezingRain,
  thunderstorm,
  snow,
  fog,
  haze,
}

class HourForecast {
  const HourForecast({
    required this.time,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.rainChance,
    required this.precipitation,
    required this.humidity,
    required this.windSpeed,
  });

  final DateTime time;
  final int temperature;
  final int feelsLike;
  final WeatherCondition condition;
  final int rainChance;
  final double precipitation;
  final int humidity;
  final double windSpeed;

  HourForecast copyWith({WeatherCondition? condition, int? rainChance}) {
    return HourForecast(
      time: time,
      temperature: temperature,
      feelsLike: feelsLike,
      condition: condition ?? this.condition,
      rainChance: rainChance ?? this.rainChance,
      precipitation: precipitation,
      humidity: humidity,
      windSpeed: windSpeed,
    );
  }

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'temperature': temperature,
    'feelsLike': feelsLike,
    'condition': condition.name,
    'rainChance': rainChance,
    'precipitation': precipitation,
    'humidity': humidity,
    'windSpeed': windSpeed,
  };

  factory HourForecast.fromJson(Map<String, Object?> json) {
    return HourForecast(
      time: DateTime.parse(json['time']! as String),
      temperature: json['temperature']! as int,
      feelsLike: json['feelsLike']! as int,
      condition: WeatherCondition.values.byName(json['condition']! as String),
      rainChance: json['rainChance']! as int,
      precipitation: (json['precipitation']! as num).toDouble(),
      humidity: json['humidity']! as int,
      windSpeed: (json['windSpeed']! as num).toDouble(),
    );
  }
}

class DayForecast {
  const DayForecast({
    required this.date,
    required this.high,
    required this.low,
    required this.condition,
    required this.rainChance,
    required this.precipitation,
    required this.uvIndex,
    required this.sunrise,
    required this.sunset,
  });

  final DateTime date;
  final int high;
  final int low;
  final WeatherCondition condition;
  final int rainChance;
  final double precipitation;
  final double uvIndex;
  final DateTime sunrise;
  final DateTime sunset;

  DayForecast copyWith({WeatherCondition? condition, int? rainChance}) {
    return DayForecast(
      date: date,
      high: high,
      low: low,
      condition: condition ?? this.condition,
      rainChance: rainChance ?? this.rainChance,
      precipitation: precipitation,
      uvIndex: uvIndex,
      sunrise: sunrise,
      sunset: sunset,
    );
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'high': high,
    'low': low,
    'condition': condition.name,
    'rainChance': rainChance,
    'precipitation': precipitation,
    'uvIndex': uvIndex,
    'sunrise': sunrise.toIso8601String(),
    'sunset': sunset.toIso8601String(),
  };

  factory DayForecast.fromJson(Map<String, Object?> json) {
    return DayForecast(
      date: DateTime.parse(json['date']! as String),
      high: json['high']! as int,
      low: json['low']! as int,
      condition: WeatherCondition.values.byName(json['condition']! as String),
      rainChance: json['rainChance']! as int,
      precipitation: (json['precipitation']! as num).toDouble(),
      uvIndex: (json['uvIndex']! as num).toDouble(),
      sunrise: DateTime.parse(json['sunrise']! as String),
      sunset: DateTime.parse(json['sunset']! as String),
    );
  }
}

class WeatherAlert {
  const WeatherAlert({
    required this.title,
    required this.level,
    this.description = '',
    this.instruction = '',
    this.source = '',
  });

  final String title;
  final String level;
  final String description;
  final String instruction;
  final String source;

  Map<String, Object?> toJson() => {
    'title': title,
    'level': level,
    'description': description,
    'instruction': instruction,
    'source': source,
  };

  factory WeatherAlert.fromJson(Map<String, Object?> json) {
    return WeatherAlert(
      title: json['title']! as String,
      level: json['level']! as String,
      description: json['description']! as String,
      instruction: json['instruction'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

class WeatherReport {
  const WeatherReport({
    required this.city,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    required this.temperature,
    required this.feelsLike,
    required this.high,
    required this.low,
    required this.condition,
    required this.summary,
    required this.rainChance,
    required this.precipitation,
    required this.humidity,
    required this.dewPoint,
    required this.windDirection,
    required this.windDegrees,
    required this.windLevel,
    required this.windSpeed,
    required this.windGust,
    required this.airQuality,
    required this.airQualityIndex,
    required this.pm25,
    required this.uvIndex,
    required this.visibility,
    required this.pressure,
    required this.cloudCover,
    required this.sunrise,
    required this.sunset,
    required this.isDay,
    required this.hourly,
    required this.daily,
    required this.alerts,
    this.airQualityAvailable = true,
    this.isCached = false,
  });

  final String city;
  final String district;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final int temperature;
  final int feelsLike;
  final int high;
  final int low;
  final WeatherCondition condition;
  final String summary;
  final int rainChance;
  final double precipitation;
  final int humidity;
  final int dewPoint;
  final String windDirection;
  final int windDegrees;
  final int windLevel;
  final double windSpeed;
  final double windGust;
  final String airQuality;
  final int airQualityIndex;
  final double pm25;
  final bool airQualityAvailable;
  final double uvIndex;
  final double visibility;
  final int pressure;
  final int cloudCover;
  final DateTime sunrise;
  final DateTime sunset;
  final bool isDay;
  final List<HourForecast> hourly;
  final List<DayForecast> daily;
  final List<WeatherAlert> alerts;
  final bool isCached;

  WeatherReport copyWith({
    WeatherCondition? condition,
    String? summary,
    int? rainChance,
    List<HourForecast>? hourly,
    List<DayForecast>? daily,
    bool? airQualityAvailable,
    bool? isCached,
  }) {
    return WeatherReport(
      city: city,
      district: district,
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
      temperature: temperature,
      feelsLike: feelsLike,
      high: high,
      low: low,
      condition: condition ?? this.condition,
      summary: summary ?? this.summary,
      rainChance: rainChance ?? this.rainChance,
      precipitation: precipitation,
      humidity: humidity,
      dewPoint: dewPoint,
      windDirection: windDirection,
      windDegrees: windDegrees,
      windLevel: windLevel,
      windSpeed: windSpeed,
      windGust: windGust,
      airQuality: airQuality,
      airQualityIndex: airQualityIndex,
      pm25: pm25,
      airQualityAvailable: airQualityAvailable ?? this.airQualityAvailable,
      uvIndex: uvIndex,
      visibility: visibility,
      pressure: pressure,
      cloudCover: cloudCover,
      sunrise: sunrise,
      sunset: sunset,
      isDay: isDay,
      hourly: hourly ?? this.hourly,
      daily: daily ?? this.daily,
      alerts: alerts,
      isCached: isCached ?? this.isCached,
    );
  }

  Map<String, Object?> toJson() => {
    'city': city,
    'district': district,
    'latitude': latitude,
    'longitude': longitude,
    'updatedAt': updatedAt.toIso8601String(),
    'temperature': temperature,
    'feelsLike': feelsLike,
    'high': high,
    'low': low,
    'condition': condition.name,
    'summary': summary,
    'rainChance': rainChance,
    'precipitation': precipitation,
    'humidity': humidity,
    'dewPoint': dewPoint,
    'windDirection': windDirection,
    'windDegrees': windDegrees,
    'windLevel': windLevel,
    'windSpeed': windSpeed,
    'windGust': windGust,
    'airQuality': airQuality,
    'airQualityIndex': airQualityIndex,
    'pm25': pm25,
    'airQualityAvailable': airQualityAvailable,
    'uvIndex': uvIndex,
    'visibility': visibility,
    'pressure': pressure,
    'cloudCover': cloudCover,
    'sunrise': sunrise.toIso8601String(),
    'sunset': sunset.toIso8601String(),
    'isDay': isDay,
    'hourly': hourly.map((item) => item.toJson()).toList(),
    'daily': daily.map((item) => item.toJson()).toList(),
    'alerts': alerts.map((item) => item.toJson()).toList(),
  };

  factory WeatherReport.fromJson(Map<String, Object?> json) {
    return WeatherReport(
      city: json['city']! as String,
      district: json['district']! as String,
      latitude: (json['latitude']! as num).toDouble(),
      longitude: (json['longitude']! as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      temperature: json['temperature']! as int,
      feelsLike: json['feelsLike']! as int,
      high: json['high']! as int,
      low: json['low']! as int,
      condition: WeatherCondition.values.byName(json['condition']! as String),
      summary: json['summary']! as String,
      rainChance: json['rainChance']! as int,
      precipitation: (json['precipitation']! as num).toDouble(),
      humidity: json['humidity']! as int,
      dewPoint: json['dewPoint']! as int,
      windDirection: json['windDirection']! as String,
      windDegrees: json['windDegrees']! as int,
      windLevel: json['windLevel']! as int,
      windSpeed: (json['windSpeed']! as num).toDouble(),
      windGust: (json['windGust']! as num).toDouble(),
      airQuality: json['airQuality']! as String,
      airQualityIndex: json['airQualityIndex']! as int,
      pm25: (json['pm25']! as num).toDouble(),
      airQualityAvailable: json['airQualityAvailable'] as bool? ?? true,
      uvIndex: (json['uvIndex']! as num).toDouble(),
      visibility: (json['visibility']! as num).toDouble(),
      pressure: json['pressure']! as int,
      cloudCover: json['cloudCover']! as int,
      sunrise: DateTime.parse(json['sunrise']! as String),
      sunset: DateTime.parse(json['sunset']! as String),
      isDay: json['isDay']! as bool,
      hourly: (json['hourly']! as List<Object?>)
          .map((item) => HourForecast.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      daily: (json['daily']! as List<Object?>)
          .map((item) => DayForecast.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      alerts: (json['alerts']! as List<Object?>)
          .map((item) => WeatherAlert.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
    );
  }
}
