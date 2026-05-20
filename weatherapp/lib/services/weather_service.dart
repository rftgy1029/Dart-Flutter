import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_models.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const City seoul = City(
    name: 'Seoul',
    country: 'South Korea',
    admin1: 'Seoul',
    latitude: 37.566,
    longitude: 126.9784,
  );

  Future<List<City>> searchCities(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': trimmedQuery,
      'count': '8',
      'language': 'ko',
      'format': 'json',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherException('도시 검색에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? const [];
    return results
        .map((item) => City.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WeatherForecast> fetchForecast(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': city.latitude.toString(),
      'longitude': city.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '7',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherException('날씨 정보를 불러오지 못했어요. 네트워크를 확인해 주세요.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseForecast(city, json);
  }

  WeatherForecast _parseForecast(City city, Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    return WeatherForecast(
      city: city,
      timezone: json['timezone'] as String? ?? 'Local',
      current: CurrentWeather(
        time: DateTime.parse(current['time'] as String),
        temperature: _doubleAt(current, 'temperature_2m'),
        apparentTemperature: _doubleAt(current, 'apparent_temperature'),
        humidity: _intAt(current, 'relative_humidity_2m'),
        precipitation: _doubleAt(current, 'precipitation'),
        weatherCode: _intAt(current, 'weather_code'),
        windSpeed: _doubleAt(current, 'wind_speed_10m'),
        isDay: _intAt(current, 'is_day') == 1,
      ),
      hourly: _parseHourly(hourly),
      daily: _parseDaily(daily),
    );
  }

  List<HourlyWeather> _parseHourly(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>;
    final temperatures = hourly['temperature_2m'] as List<dynamic>;
    final probabilities = hourly['precipitation_probability'] as List<dynamic>;
    final codes = hourly['weather_code'] as List<dynamic>;

    final now = DateTime.now();
    final items = <HourlyWeather>[];

    for (var index = 0; index < times.length; index++) {
      final time = DateTime.parse(times[index] as String);
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) {
        continue;
      }

      items.add(
        HourlyWeather(
          time: time,
          temperature: (temperatures[index] as num).toDouble(),
          precipitationProbability:
              (probabilities[index] as num?)?.toInt() ?? 0,
          weatherCode: (codes[index] as num).toInt(),
        ),
      );

      if (items.length == 12) {
        break;
      }
    }

    return items;
  }

  List<DailyWeather> _parseDaily(Map<String, dynamic> daily) {
    final dates = daily['time'] as List<dynamic>;
    final maxTemps = daily['temperature_2m_max'] as List<dynamic>;
    final minTemps = daily['temperature_2m_min'] as List<dynamic>;
    final probabilities =
        daily['precipitation_probability_max'] as List<dynamic>;
    final codes = daily['weather_code'] as List<dynamic>;

    return List.generate(dates.length, (index) {
      return DailyWeather(
        date: DateTime.parse(dates[index] as String),
        maxTemperature: (maxTemps[index] as num).toDouble(),
        minTemperature: (minTemps[index] as num).toDouble(),
        precipitationProbability: (probabilities[index] as num?)?.toInt() ?? 0,
        weatherCode: (codes[index] as num).toInt(),
      );
    });
  }

  double _doubleAt(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble() ?? 0;
  }

  int _intAt(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toInt() ?? 0;
  }
}

class WeatherException implements Exception {
  WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}
