import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'screens/weather_home_page.dart';
import 'services/location_service.dart';
import 'services/murphy_weather_adapter.dart';
import 'services/open_meteo_weather_source.dart';
import 'services/qweather_alert_source.dart';
import 'services/weather_cache.dart';
import 'services/weather_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintPointersEnabled = false;
    debugRepaintRainbowEnabled = false;
    return true;
  }());
  runApp(const MurphyApp());
}

class MurphyApp extends StatelessWidget {
  const MurphyApp({super.key, this.repository});

  final WeatherRepositoryContract? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Murphy',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101820),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9EC5D4),
          brightness: Brightness.dark,
        ),
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 104,
            height: 0.94,
            fontWeight: FontWeight.w200,
            letterSpacing: -6,
          ),
          headlineMedium: TextStyle(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16, height: 1.55),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        ),
      ),
      home: WeatherHomePage(repository: repository ?? _createRepository()),
    );
  }

  WeatherRepositoryContract _createRepository() {
    return WeatherRepository(
      locationService: LocationService(),
      source: OpenMeteoWeatherSource(alertSource: QWeatherAlertSource()),
      adapter: const MurphyWeatherAdapter(),
      cache: WeatherCache(),
    );
  }
}
