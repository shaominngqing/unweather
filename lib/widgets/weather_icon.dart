import 'package:flutter/cupertino.dart';

import '../models/weather.dart';

class WeatherIcon extends StatelessWidget {
  const WeatherIcon({
    required this.condition,
    required this.size,
    this.color,
    this.isNight = false,
    super.key,
  });

  final WeatherCondition condition;
  final double size;
  final Color? color;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${weatherConditionLabel(condition)}天气图标',
      child: ExcludeSemantics(
        child: Icon(
          weatherIconData(condition, isNight: isNight),
          size: size,
          color: color,
        ),
      ),
    );
  }
}

IconData weatherIconData(WeatherCondition condition, {bool isNight = false}) {
  return switch (condition) {
    WeatherCondition.clear =>
      isNight ? CupertinoIcons.moon_stars : CupertinoIcons.sun_max,
    WeatherCondition.partlyCloudy =>
      isNight ? CupertinoIcons.cloud_moon : CupertinoIcons.cloud_sun,
    WeatherCondition.cloudy => CupertinoIcons.cloud,
    WeatherCondition.lightRain => CupertinoIcons.cloud_drizzle,
    WeatherCondition.rain => CupertinoIcons.cloud_rain,
    WeatherCondition.heavyRain => CupertinoIcons.cloud_heavyrain,
    WeatherCondition.freezingRain => CupertinoIcons.cloud_sleet,
    WeatherCondition.thunderstorm => CupertinoIcons.cloud_bolt_rain,
    WeatherCondition.snow => CupertinoIcons.cloud_snow,
    WeatherCondition.fog => CupertinoIcons.cloud_fog,
    WeatherCondition.haze => CupertinoIcons.sun_haze,
  };
}

String weatherConditionLabel(WeatherCondition condition) {
  return switch (condition) {
    WeatherCondition.clear => '晴',
    WeatherCondition.partlyCloudy => '多云',
    WeatherCondition.cloudy => '阴',
    WeatherCondition.lightRain => '小雨',
    WeatherCondition.rain => '阵雨',
    WeatherCondition.heavyRain => '大雨',
    WeatherCondition.freezingRain => '冻雨',
    WeatherCondition.thunderstorm => '雷阵雨',
    WeatherCondition.snow => '雪',
    WeatherCondition.fog => '雾',
    WeatherCondition.haze => '霾',
  };
}
