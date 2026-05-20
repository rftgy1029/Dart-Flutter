import 'package:flutter/material.dart';

import '../models/weather_models.dart';
import '../services/weather_service.dart';

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({required this.initialCity, super.key});

  final City initialCity;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final _service = WeatherService();
  final _searchController = TextEditingController();

  WeatherForecast? _forecast;
  List<City> _suggestions = const [];
  String? _error;
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadForecast(widget.initialCity);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadForecast(City city) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _suggestions = const [];
    });

    try {
      final forecast = await _service.fetchForecast(city);
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _isLoading = false;
      });
    } on WeatherException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('예상하지 못한 문제가 생겼어요. 다시 시도해 주세요.');
    }
  }

  Future<void> _searchCities() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final cities = await _service.searchCities(query);
      if (!mounted) return;

      setState(() {
        _suggestions = cities;
        _isSearching = false;
        if (cities.isEmpty) {
          _error = '검색 결과가 없어요. 도시 이름을 조금 다르게 입력해 보세요.';
        }
      });
    } on WeatherException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '도시를 찾는 중 문제가 생겼어요.';
        _isSearching = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isLoading = false;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WeatherApp'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: forecast == null
                ? null
                : () => _loadForecast(forecast.city),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SearchPanel(
                            controller: _searchController,
                            isSearching: _isSearching,
                            suggestions: _suggestions,
                            onSearch: _searchCities,
                            onSelectCity: (city) {
                              _searchController.text = city.name;
                              _loadForecast(city);
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            _ErrorPanel(
                              message: _error!,
                              onRetry: forecast == null
                                  ? () => _loadForecast(widget.initialCity)
                                  : () => _loadForecast(forecast.city),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isLoading && forecast == null)
                            const _LoadingPanel()
                          else if (forecast != null) ...[
                            _CurrentWeatherPanel(forecast: forecast),
                            const SizedBox(height: 16),
                            _MetricsGrid(current: forecast.current),
                            const SizedBox(height: 16),
                            _HourlyForecastSection(hours: forecast.hourly),
                            const SizedBox(height: 16),
                            _DailyForecastSection(days: forecast.daily),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isLoading && forecast != null) const _LoadingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.isSearching,
    required this.suggestions,
    required this.onSearch,
    required this.onSelectCity,
  });

  final TextEditingController controller;
  final bool isSearching;
  final List<City> suggestions;
  final VoidCallback onSearch;
  final ValueChanged<City> onSelectCity;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    decoration: const InputDecoration(
                      hintText: '도시 검색',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: isSearching ? null : onSearch,
                    icon: isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    label: const Text('검색'),
                  ),
                ),
              ],
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((city) {
                    return ActionChip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      label: Text(city.displayName),
                      onPressed: () => onSelectCity(city),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentWeatherPanel extends StatelessWidget {
  const _CurrentWeatherPanel({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final current = forecast.current;
    final colors = current.isDay
        ? const [Color(0xFF0EA5E9), Color(0xFF22C55E)]
        : const [Color(0xFF1E293B), Color(0xFF7C3AED)];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final temperature = Text(
            '${current.temperature.round()}°',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          );

          final details = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Icon(
                weatherIcon(current.weatherCode),
                color: Colors.white,
                size: compact ? 62 : 78,
              ),
              const SizedBox(height: 8),
              Text(
                weatherLabel(current.weatherCode),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '체감 ${current.apparentTemperature.round()}°',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaceTitle(forecast: forecast),
                    const SizedBox(height: 20),
                    temperature,
                    const SizedBox(height: 12),
                    details,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PlaceTitle(forecast: forecast),
                          const SizedBox(height: 30),
                          temperature,
                        ],
                      ),
                    ),
                    details,
                  ],
                );
        },
      ),
    );
  }
}

class _PlaceTitle extends StatelessWidget {
  const _PlaceTitle({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          forecast.city.displayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatDateTime(forecast.current.time)} · ${forecast.timezone}',
          style: const TextStyle(color: Color(0xFFEFFDF7)),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.current});

  final CurrentWeather current;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricItem(
        icon: Icons.water_drop_outlined,
        label: '습도',
        value: '${current.humidity}%',
        color: const Color(0xFF2563EB),
      ),
      _MetricItem(
        icon: Icons.air_rounded,
        label: '바람',
        value: '${current.windSpeed.toStringAsFixed(1)} km/h',
        color: const Color(0xFF0F766E),
      ),
      _MetricItem(
        icon: Icons.umbrella_outlined,
        label: '강수량',
        value: '${current.precipitation.toStringAsFixed(1)} mm',
        color: const Color(0xFFF97316),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 1 : 3;
        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 4.6 : 2.7,
          ),
          itemBuilder: (context, index) => metrics[index],
        );
      },
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyForecastSection extends StatelessWidget {
  const _HourlyForecastSection({required this.hours});

  final List<HourlyWeather> hours;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '시간별 예보',
      child: SizedBox(
        height: 158,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hours.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final hour = hours[index];
            return SizedBox(
              width: 104,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatHour(hour.time),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Icon(
                        weatherIcon(hour.weatherCode),
                        size: 34,
                        color: const Color(0xFF0F766E),
                      ),
                      Text(
                        '${hour.temperature.round()}°',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          Text('${hour.precipitationProbability}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DailyForecastSection extends StatelessWidget {
  const _DailyForecastSection({required this.days});

  final List<DailyWeather> days;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '7일 예보',
      child: Column(
        children: days.map((day) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(
                        formatDay(day.date),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(
                      weatherIcon(day.weatherCode),
                      color: const Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        weatherLabel(day.weatherCode),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.water_drop_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    Text('${day.precipitationProbability}%'),
                    const SizedBox(width: 14),
                    Text(
                      '${day.minTemperature.round()}° / ${day.maxTemperature.round()}°',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        child,
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18)),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '날씨 불러오는 중',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String weatherLabel(int code) {
  if (code == 0) return '맑음';
  if (code == 1 || code == 2) return '대체로 맑음';
  if (code == 3) return '흐림';
  if (code == 45 || code == 48) return '안개';
  if (code >= 51 && code <= 57) return '이슬비';
  if (code >= 61 && code <= 67) return '비';
  if (code >= 71 && code <= 77) return '눈';
  if (code >= 80 && code <= 82) return '소나기';
  if (code >= 85 && code <= 86) return '눈 소나기';
  if (code >= 95) return '뇌우';
  return '변화 있음';
}

IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code == 1 || code == 2) return Icons.wb_twilight_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 86) return Icons.umbrella_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.filter_drama_rounded;
}

String formatDateTime(DateTime time) {
  return '${time.month}월 ${time.day}일 ${formatHour(time)}';
}

String formatHour(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  return '$hour:00';
}

String formatDay(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}/${date.day} ${weekdays[date.weekday - 1]}';
}
