import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murphy/models/weather.dart';
import 'package:murphy/widgets/weather_icon.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await loader.load();
  });

  test('uses a distinct ready-made glyph for every weather condition', () {
    final glyphs = {
      for (final condition in WeatherCondition.values)
        weatherIconData(condition).codePoint,
    };

    expect(glyphs, hasLength(WeatherCondition.values.length));
    expect(
      weatherIconData(WeatherCondition.clear, isNight: true),
      isNot(weatherIconData(WeatherCondition.clear)),
    );
    expect(
      weatherIconData(WeatherCondition.partlyCloudy, isNight: true),
      isNot(weatherIconData(WeatherCondition.partlyCloudy)),
    );
  });

  testWidgets('renders every condition at compact and large sizes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF274553),
            body: Wrap(
              children: [
                for (final condition in WeatherCondition.values)
                  WeatherIcon(condition: condition, size: 22),
                for (final condition in WeatherCondition.values)
                  WeatherIcon(condition: condition, size: 62),
                const WeatherIcon(
                  condition: WeatherCondition.clear,
                  size: 62,
                  isNight: true,
                ),
                const WeatherIcon(
                  condition: WeatherCondition.partlyCloudy,
                  size: 62,
                  isNight: true,
                ),
              ],
            ),
          ),
        ),
      );

      for (final condition in WeatherCondition.values) {
        expect(
          find.bySemanticsLabel('${weatherConditionLabel(condition)}天气图标'),
          findsWidgets,
        );
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('matches the reviewed weather icon sheet', (tester) async {
    const variants = [
      (WeatherCondition.clear, false),
      (WeatherCondition.partlyCloudy, false),
      (WeatherCondition.cloudy, false),
      (WeatherCondition.lightRain, false),
      (WeatherCondition.rain, false),
      (WeatherCondition.heavyRain, false),
      (WeatherCondition.freezingRain, false),
      (WeatherCondition.thunderstorm, false),
      (WeatherCondition.snow, false),
      (WeatherCondition.fog, false),
      (WeatherCondition.haze, false),
      (WeatherCondition.clear, true),
      (WeatherCondition.partlyCloudy, true),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('weather-icon-sheet'),
              child: ColoredBox(
                color: const Color(0xFF274553),
                child: SizedBox(
                  width: 288,
                  height: 288,
                  child: Wrap(
                    children: [
                      for (final variant in variants)
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Center(
                            child: WeatherIcon(
                              condition: variant.$1,
                              size: 52,
                              color: Colors.white,
                              isNight: variant.$2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('weather-icon-sheet')),
      matchesGoldenFile('goldens/weather_icons.png'),
    );
  }, skip: !Platform.isMacOS);
}
