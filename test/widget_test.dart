import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murphy/main.dart';

import 'test_weather.dart';

void main() {
  testWidgets('renders the detailed Murphy weather home screen', (
    tester,
  ) async {
    final repository = FakeWeatherRepository(testWeather());
    await tester.pumpWidget(MurphyApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('MURPHY'), findsOneWidget);
    expect(find.text('广州市 · 天河区'), findsOneWidget);
    expect(find.text('31°'), findsWidgets);
    expect(find.text('24 小时预报'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('10 日天气预报'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('10 日天气预报'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('空气质量'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('空气质量'), findsOneWidget);
  });

  testWidgets('supports pull to refresh', (tester) async {
    final repository = FakeWeatherRepository(testWeather());
    await tester.pumpWidget(MurphyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.drag(find.text('MURPHY'), const Offset(0, 420));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('广州市 · 天河区'), findsOneWidget);
  });
}
