import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/resolved_location.dart';
import '../models/weather.dart';
import '../services/location_service.dart';
import '../services/weather_repository.dart';
import '../widgets/weather_icon.dart';

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({required this.repository, super.key});

  final WeatherRepositoryContract repository;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage>
    with WidgetsBindingObserver {
  WeatherReport? _report;
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreCacheAndRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _error is LocationFailure) {
      _loadCurrentLocation();
    }
  }

  Future<void> _restoreCacheAndRefresh() async {
    final cached = await widget.repository.loadCachedWeather();
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _report = cached;
        _loading = false;
      });
    }
    await _loadCurrentLocation(showLoading: cached == null);
  }

  Future<void> _loadCurrentLocation({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      final report = await widget.repository.fetchCurrentLocation();
      if (!mounted) return;
      setState(() {
        _report = report;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _openCitySearch() async {
    final result = await showModalBottomSheet<WeatherReport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CitySearchSheet(repository: widget.repository),
    );
    if (result != null && mounted) {
      setState(() {
        _report = result;
        _error = null;
      });
    }
  }

  Future<void> _openSettings(LocationFailure failure) async {
    if (failure.kind == LocationFailureKind.servicesDisabled) {
      await widget.repository.openLocationSettings();
    } else {
      await widget.repository.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    late final Widget content;

    if (_loading && _report == null) {
      content = const _LoadingState();
    } else if (_error != null && _report == null) {
      content = _ErrorState(
        error: _error!,
        onRetry: _loadCurrentLocation,
        onSettings: _error is LocationFailure
            ? () => _openSettings(_error! as LocationFailure)
            : null,
        onSearch: _openCitySearch,
      );
    } else {
      content = _WeatherView(
        report: _report!,
        refreshing: _refreshing,
        onRefresh: () => _loadCurrentLocation(showLoading: false),
        onSearch: _openCitySearch,
      );
    }

    return Scaffold(backgroundColor: Colors.transparent, body: content);
  }
}

class _WeatherView extends StatelessWidget {
  const _WeatherView({
    required this.report,
    required this.refreshing,
    required this.onRefresh,
    required this.onSearch,
  });

  final WeatherReport report;
  final bool refreshing;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _WeatherBackground(report: report)),
        Positioned.fill(
          child: RefreshIndicator(
            color: Colors.white,
            backgroundColor: const Color(0xFF20313C),
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 38),
                    sliver: SliverList.list(
                      children: [
                        _Header(
                          report: report,
                          refreshing: refreshing,
                          onLocate: onRefresh,
                          onSearch: onSearch,
                        ),
                        const SizedBox(height: 30),
                        _CurrentWeather(report: report),
                        if (report.alerts.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _AlertCard(alert: report.alerts.first),
                        ],
                        const SizedBox(height: 28),
                        _HourlyForecastCard(
                          items: report.hourly,
                          days: report.daily,
                        ),
                        const SizedBox(height: 12),
                        _PrecipitationCard(items: report.hourly),
                        const SizedBox(height: 12),
                        _DailyForecastCard(items: report.daily),
                        const SizedBox(height: 12),
                        _AirQualityCard(report: report),
                        const SizedBox(height: 12),
                        _DetailsGrid(report: report),
                        const SizedBox(height: 24),
                        _Footer(report: report),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.report,
    required this.refreshing,
    required this.onLocate,
    required this.onSearch,
  });

  final WeatherReport report;
  final bool refreshing;
  final VoidCallback onLocate;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'MURPHY',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.2,
                    ),
                  ),
                  if (report.isCached) ...[
                    const SizedBox(width: 10),
                    _StatusPill(label: '离线数据'),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 15),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${report.city} · ${report.district}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _RoundButton(
          icon: Icons.search_rounded,
          semanticLabel: '搜索城市',
          onPressed: onSearch,
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: refreshing ? null : Icons.my_location_rounded,
          semanticLabel: '使用当前位置',
          onPressed: onLocate,
          child: refreshing
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _CurrentWeather extends StatelessWidget {
  const _CurrentWeather({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label:
          '${report.city}${report.district}，当前${weatherConditionLabel(report.condition)}，'
          '${report.temperature}度，最高${report.high}度，最低${report.low}度。'
          '${report.summary}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            WeatherIcon(
              condition: report.condition,
              size: 62,
              color: Colors.white.withValues(alpha: 0.96),
              isNight: !report.isDay,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${report.temperature}°',
                style: theme.textTheme.displayLarge,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              weatherConditionLabel(report.condition),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '最高 ${report.high}°  最低 ${report.low}°',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Text(
                report.summary,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      tint: const Color(0xFFB55B3C),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 25),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (alert.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    alert.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _secondaryStyle(12),
                  ),
                ],
                if (alert.source.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(alert.source, style: _secondaryStyle(10)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyForecastCard extends StatelessWidget {
  const _HourlyForecastCard({required this.items, required this.days});

  final List<HourForecast> items;
  final List<DayForecast> days;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(24).toList(growable: false);
    final temperatures = visible.map((item) => item.temperature).toList();
    final minTemperature = temperatures.reduce(math.min);
    final maxTemperature = temperatures.reduce(math.max);
    const itemWidth = 62.0;

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(0, 17, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 17),
            child: _SectionTitle(
              title: '24 小时预报',
              icon: Icons.schedule_rounded,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: visible.length * itemWidth,
              height: 174,
              child: Stack(
                children: [
                  Positioned(
                    left: itemWidth / 2,
                    right: itemWidth / 2,
                    top: 77,
                    height: 43,
                    child: CustomPaint(
                      painter: _TemperatureLinePainter(
                        temperatures: temperatures,
                        minimum: minTemperature,
                        maximum: maxTemperature,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < visible.length; index++)
                        SizedBox(
                          width: itemWidth,
                          child: _HourColumn(
                            item: visible[index],
                            isNow: index == 0,
                            isNight: _isNightAt(visible[index].time, days),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourColumn extends StatelessWidget {
  const _HourColumn({
    required this.item,
    required this.isNow,
    required this.isNight,
  });

  final HourForecast item;
  final bool isNow;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isNow ? '现在' : '${_twoDigits(item.time.hour)}时',
          style: _secondaryStyle(12),
        ),
        const SizedBox(height: 10),
        WeatherIcon(condition: item.condition, size: 23, isNight: isNight),
        const SizedBox(height: 10),
        Text(
          '${item.temperature}°',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 49),
        Text(
          '${item.rainChance}%',
          style: const TextStyle(color: Color(0xFF9EDCF1), fontSize: 11),
        ),
      ],
    );
  }
}

class _TemperatureLinePainter extends CustomPainter {
  _TemperatureLinePainter({
    required this.temperatures,
    required this.minimum,
    required this.maximum,
  });

  final List<int> temperatures;
  final int minimum;
  final int maximum;

  @override
  void paint(Canvas canvas, Size size) {
    if (temperatures.length < 2) return;
    final range = math.max(1, maximum - minimum);
    final path = Path();
    for (var index = 0; index < temperatures.length; index++) {
      final x = size.width * index / (temperatures.length - 1);
      final normalized = (temperatures[index] - minimum) / range;
      final y = size.height - 5 - normalized * (size.height - 10);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TemperatureLinePainter oldDelegate) {
    return oldDelegate.temperatures != temperatures;
  }
}

class _PrecipitationCard extends StatelessWidget {
  const _PrecipitationCard({required this.items});

  final List<HourForecast> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(12).toList(growable: false);
    final peak = visible.map((item) => item.rainChance).fold(0, math.max);
    final description = peak >= 70
        ? '未来 12 小时降水概率较高'
        : peak >= 35
        ? '未来 12 小时可能有短时降水'
        : '未来 12 小时降水概率较低';

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '降水', icon: Icons.water_drop_outlined),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 66,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < visible.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: math.max(
                                  0.06,
                                  visible[index].rainChance / 100,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF91D9F2,
                                    ).withValues(alpha: 0.75),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          if (index % 3 == 0)
                            Text(
                              index == 0
                                  ? '现在'
                                  : '${_twoDigits(visible[index].time.hour)}时',
                              style: _secondaryStyle(9),
                            )
                          else
                            const SizedBox(height: 13),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyForecastCard extends StatelessWidget {
  const _DailyForecastCard({required this.items});

  final List<DayForecast> items;

  @override
  Widget build(BuildContext context) {
    final minimum = items.map((item) => item.low).reduce(math.min);
    final maximum = items.map((item) => item.high).reduce(math.max);
    return _GlassCard(
      child: Column(
        children: [
          const _SectionTitle(
            title: '10 日天气预报',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 7),
          for (var index = 0; index < items.length; index++) ...[
            _DailyRow(
              item: items[index],
              isToday: index == 0,
              globalMinimum: minimum,
              globalMaximum: maximum,
            ),
            if (index != items.length - 1)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.075)),
          ],
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.item,
    required this.isToday,
    required this.globalMinimum,
    required this.globalMaximum,
  });

  final DayForecast item;
  final bool isToday;
  final int globalMinimum;
  final int globalMaximum;

  @override
  Widget build(BuildContext context) {
    final totalRange = math.max(1, globalMaximum - globalMinimum);
    final start = (item.low - globalMinimum) / totalRange;
    final width = math.max(0.12, (item.high - item.low) / totalRange);
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              isToday ? '今天' : _weekday(item.date),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 31,
            child: Center(
              child: WeatherIcon(condition: item.condition, size: 22),
            ),
          ),
          SizedBox(
            width: 37,
            child: Text(
              '${item.rainChance}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF9EDCF1), fontSize: 11),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 34,
            child: Text(
              '${item.low}°',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Positioned(
                      left: constraints.maxWidth * start,
                      width: constraints.maxWidth * math.min(width, 1 - start),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF78C7E4), Color(0xFFF2CF71)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '${item.high}°',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirQualityCard extends StatelessWidget {
  const _AirQualityCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.airQualityAvailable) {
      return const _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: '空气质量', icon: Icons.eco_outlined),
            SizedBox(height: 14),
            Text('--', style: TextStyle(fontSize: 34, height: 1)),
            SizedBox(height: 8),
            Text(
              '空气质量服务暂时不可用',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final marker = (report.airQualityIndex.clamp(0, 300) / 300).toDouble();
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '空气质量', icon: Icons.eco_outlined),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${report.airQualityIndex}',
                style: const TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  report.airQuality,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const Spacer(),
              Text(
                'PM2.5  ${report.pm25.toStringAsFixed(0)}',
                style: _secondaryStyle(12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF65C995),
                          Color(0xFFE1D46A),
                          Color(0xFFE79250),
                          Color(0xFFC85A63),
                          Color(0xFF855695),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth * marker - 4,
                    top: -3,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final singleColumn = textScale > 1.3;
    return GridView.count(
      crossAxisCount: singleColumn ? 1 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: singleColumn ? 2.1 : 0.98,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _UvCard(report: report),
        _SunCard(report: report),
        _WindCard(report: report),
        _MetricCard(
          icon: Icons.device_thermostat_rounded,
          title: '体感温度',
          value: '${report.feelsLike}°',
          caption: _feelsLikeCaption(report),
        ),
        _MetricCard(
          icon: Icons.water_drop_outlined,
          title: '湿度',
          value: '${report.humidity}%',
          caption: '露点温度 ${report.dewPoint}°',
        ),
        _MetricCard(
          icon: Icons.visibility_outlined,
          title: '能见度',
          value: '${report.visibility.toStringAsFixed(1)} km',
          caption: report.visibility >= 10 ? '视野清晰' : '能见度有所下降',
        ),
        _PressureCard(report: report),
        _MetricCard(
          icon: Icons.umbrella_outlined,
          title: '降水量',
          value: '${report.precipitation.toStringAsFixed(1)} mm',
          caption: '当前降水概率 ${report.rainChance}%',
        ),
        _MetricCard(
          icon: Icons.cloud_outlined,
          title: '云量',
          value: '${report.cloudCover}%',
          caption: _cloudCaption(report.cloudCover),
        ),
        _MetricCard(
          icon: Icons.air_rounded,
          title: '阵风',
          value: '${report.windGust.toStringAsFixed(0)} km/h',
          caption: '持续风速 ${report.windSpeed.toStringAsFixed(0)} km/h',
        ),
      ],
    );
  }
}

class _UvCard extends StatelessWidget {
  const _UvCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final level = report.uvIndex;
    return _MetricCard(
      icon: Icons.wb_sunny_outlined,
      title: '紫外线指数',
      value: level.toStringAsFixed(1),
      caption: level < 3
          ? '较弱'
          : level < 6
          ? '中等，外出建议防晒'
          : '较强，注意防晒',
      footer: _ProgressTrack(value: (level / 11).clamp(0, 1)),
    );
  }
}

class _SunCard extends StatelessWidget {
  const _SunCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final now = report.updatedAt;
    final total = report.sunset.difference(report.sunrise).inMinutes;
    final elapsed = now.difference(report.sunrise).inMinutes;
    final progress = total <= 0 ? 0.0 : (elapsed / total).clamp(0.0, 1.0);
    final nextTitle = now.isBefore(report.sunset) ? '日落' : '日出';
    final nextTime = now.isBefore(report.sunset)
        ? report.sunset
        : report.daily.length > 1
        ? report.daily[1].sunrise
        : report.sunrise.add(const Duration(days: 1));
    return _GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: nextTitle, icon: Icons.wb_twilight_outlined),
          const SizedBox(height: 11),
          Text(
            _time(nextTime),
            style: const TextStyle(
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: CustomPaint(painter: _SunArcPainter(progress: progress)),
          ),
          Text('日出 ${_time(report.sunrise)}', style: _secondaryStyle(11)),
        ],
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  _SunArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 8, size.width - 8, size.height * 1.2);
    final base = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    canvas.drawLine(
      Offset(0, size.height - 2),
      Offset(size.width, size.height - 2),
      base,
    );
    final angle = math.pi + math.pi * progress;
    final center = rect.center;
    final point = Offset(
      center.dx + rect.width / 2 * math.cos(angle),
      center.dy + rect.height / 2 * math.sin(angle),
    );
    canvas.drawCircle(point, 4.5, Paint()..color = const Color(0xFFFFD272));
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _WindCard extends StatelessWidget {
  const _WindCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '风', icon: Icons.air_rounded),
          const Spacer(),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const _CompassFace(),
                    Transform.rotate(
                      angle: report.windDegrees * math.pi / 180,
                      child: const Icon(Icons.navigation_rounded, size: 27),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.windLevel}级',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(report.windDirection, style: _secondaryStyle(12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompassFace extends StatelessWidget {
  const _CompassFace();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: const Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Text('北', style: TextStyle(fontSize: 9)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Text('南', style: TextStyle(fontSize: 9)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('西', style: TextStyle(fontSize: 9)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('东', style: TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }
}

class _PressureCard extends StatelessWidget {
  const _PressureCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      icon: Icons.speed_rounded,
      title: '气压',
      value: '${report.pressure}',
      caption: 'hPa',
      footer: CustomPaint(
        size: const Size(double.infinity, 19),
        painter: _PressureScalePainter(pressure: report.pressure),
      ),
    );
  }
}

class _PressureScalePainter extends CustomPainter {
  _PressureScalePainter({required this.pressure});

  final int pressure;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 10), Offset(size.width, 10), base);
    for (var i = 0; i <= 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 7), Offset(x, i.isEven ? 14 : 12), base);
    }
    final marker = ((pressure - 960) / 100).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(size.width * marker, 10),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PressureScalePainter oldDelegate) {
    return oldDelegate.pressure != pressure;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title, icon: icon),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 25,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _secondaryStyle(11),
          ),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD272)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.55)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (tint ?? Colors.white).withValues(
          alpha: tint == null ? 0.075 : 0.22,
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.child,
  });

  final IconData? icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        onPressed: onPressed,
        icon: child ?? Icon(icon, size: 19),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: _secondaryStyle(9)),
    );
  }
}

class _WeatherBackground extends StatelessWidget {
  const _WeatherBackground({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final colors = _backgroundColors(report.condition, report.isDay);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: Container(
              width: 390,
              height: 390,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: report.isDay ? 0.07 : 0.035,
                ),
              ),
            ),
          ),
          Positioned(
            top: 480,
            left: -220,
            child: Container(
              width: 470,
              height: 470,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.025),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          report.isCached ? '当前显示上次成功更新的数据' : '更新于 ${_time(report.updatedAt)}',
          style: _secondaryStyle(11),
        ),
        const SizedBox(height: 5),
        Text(
          '${report.latitude.toStringAsFixed(2)}°, ${report.longitude.toStringAsFixed(2)}°',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          report.alerts.isEmpty
              ? '天气数据：Open-Meteo'
              : '天气数据：Open-Meteo · 预警数据：和风天气',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 3),
        TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const _PrivacySheet(),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white54,
            textStyle: const TextStyle(fontSize: 10),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('隐私与数据说明'),
        ),
      ],
    );
  }
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF172832),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '隐私与数据说明',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                'Murphy 仅在前台使用定位来查询当地天气。发送到天气服务的坐标会被降低到小数点后两位，应用不要求注册账号，也不会用于广告追踪。',
                style: _secondaryStyle(14),
              ),
              const SizedBox(height: 12),
              Text(
                '天气数据来自 Open-Meteo；配置官方预警服务后，坐标也会用于查询和风天气发布的官方预警。本地仅保存最近使用地点的天气缓存，可通过卸载应用清除。',
                style: _secondaryStyle(14),
              ),
              const SizedBox(height: 12),
              Text(
                '你可以随时在系统设置中关闭 Murphy 的定位权限，并继续通过城市搜索查看天气。',
                style: _secondaryStyle(14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF173343),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MURPHY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 28),
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              SizedBox(height: 18),
              Text('正在获取当前位置', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.onSearch,
    this.onSettings,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onSearch;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final isLocation = error is LocationFailure;
    final message = isLocation
        ? (error as LocationFailure).message
        : '暂时无法获取天气数据';
    return ColoredBox(
      color: const Color(0xFF173343),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLocation
                    ? Icons.location_off_rounded
                    : Icons.cloud_off_rounded,
                size: 46,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isLocation ? 'Murphy 需要当前位置来提供当地天气。' : '请检查网络连接后重试。',
                textAlign: TextAlign.center,
                style: _secondaryStyle(14),
              ),
              const SizedBox(height: 25),
              if (onSettings != null)
                FilledButton(onPressed: onSettings, child: const Text('打开系统设置'))
              else
                FilledButton(onPressed: onRetry, child: const Text('重新加载')),
              const SizedBox(height: 9),
              TextButton(onPressed: onSearch, child: const Text('搜索其他城市')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CitySearchSheet extends StatefulWidget {
  const _CitySearchSheet({required this.repository});

  final WeatherRepositoryContract repository;

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _controller = TextEditingController();
  List<ResolvedLocation> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await widget.repository.searchLocations(_controller.text);
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() => _results = results);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectLocation(ResolvedLocation location) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final report = await widget.repository.fetchLocation(location);
      if (mounted) Navigator.of(context).pop(report);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF172832),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '搜索城市',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '城市或区县名称',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final location = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(location.city),
                      subtitle: Text(
                        '${location.district} · '
                        '${location.latitude.toStringAsFixed(2)}, '
                        '${location.longitude.toStringAsFixed(2)}',
                        style: _secondaryStyle(11),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _searching
                          ? null
                          : () => _selectLocation(location),
                    );
                  },
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFFA690), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_results.isEmpty ? '搜索城市' : '重新搜索'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Color> _backgroundColors(WeatherCondition condition, bool isDay) {
  if (!isDay) {
    return const [Color(0xFF162B42), Color(0xFF101C2B), Color(0xFF080F18)];
  }
  return switch (condition) {
    WeatherCondition.clear => const [
      Color(0xFF4383B4),
      Color(0xFF266089),
      Color(0xFF15344B),
    ],
    WeatherCondition.partlyCloudy => const [
      Color(0xFF4E7E9B),
      Color(0xFF315D75),
      Color(0xFF183A4A),
    ],
    WeatherCondition.cloudy || WeatherCondition.haze => const [
      Color(0xFF657681),
      Color(0xFF465A66),
      Color(0xFF273A44),
    ],
    _ => const [Color(0xFF3D6074), Color(0xFF274553), Color(0xFF142D38)],
  };
}

bool _isNightAt(DateTime time, List<DayForecast> days) {
  for (final day in days) {
    final sameDate =
        day.date.year == time.year &&
        day.date.month == time.month &&
        day.date.day == time.day;
    if (sameDate) {
      return time.isBefore(day.sunrise) || !time.isBefore(day.sunset);
    }
  }
  return time.hour < 6 || time.hour >= 18;
}

String _weekday(DateTime date) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[date.weekday - 1];
}

String _time(DateTime value) =>
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _feelsLikeCaption(WeatherReport report) {
  final difference = report.feelsLike - report.temperature;
  if (difference >= 2) return '体感比实际温度偏高';
  if (difference <= -2) return '体感比实际温度偏低';
  return '与实际温度接近';
}

String _cloudCaption(int cloudCover) {
  if (cloudCover < 20) return '天空较为晴朗';
  if (cloudCover < 70) return '有不同程度云层';
  return '云层覆盖较多';
}

TextStyle _secondaryStyle(double size) {
  return TextStyle(color: Colors.white.withValues(alpha: 0.56), fontSize: size);
}
