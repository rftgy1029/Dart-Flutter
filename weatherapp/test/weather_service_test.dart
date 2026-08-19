import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weatherapp/models/weather_models.dart';
import 'package:weatherapp/services/weather_service.dart';

void main() {
  const city = City(
    name: 'Seoul',
    country: 'South Korea',
    latitude: 37.566,
    longitude: 126.9784,
  );

  test('empty city search does not make a request', () async {
    final service = WeatherService(
      client: MockClient((_) async => throw StateError('unexpected request')),
    );

    expect(await service.searchCities('   '), isEmpty);
    service.close();
  });

  test('forecast keeps the current and next hourly entries', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.open-meteo.com');
      return http.Response(
        jsonEncode({
          'timezone': 'Asia/Seoul',
          'current': {
            'time': '2026-08-19T10:00',
            'temperature_2m': 28.4,
            'relative_humidity_2m': 62,
            'apparent_temperature': 30.1,
            'is_day': 1,
            'precipitation': 0,
            'weather_code': 1,
            'wind_speed_10m': 7.2,
          },
          'hourly': {
            'time': [
              '2026-08-19T09:00',
              '2026-08-19T10:00',
              '2026-08-19T11:00',
            ],
            'temperature_2m': [27.0, 28.4, 29.0],
            'precipitation_probability': [10, null, 20],
            'weather_code': [2, 1, 1],
          },
          'daily': {
            'time': ['2026-08-19'],
            'temperature_2m_max': [31.0],
            'temperature_2m_min': [24.0],
            'precipitation_probability_max': [20],
            'weather_code': [1],
          },
        }),
        200,
      );
    });
    final service = WeatherService(client: client);

    final forecast = await service.fetchForecast(city);

    expect(forecast.timezone, 'Asia/Seoul');
    expect(forecast.current.temperature, 28.4);
    expect(forecast.hourly, hasLength(2));
    expect(forecast.hourly.first.time.hour, 10);
    expect(forecast.hourly.first.precipitationProbability, 0);
    expect(forecast.daily.single.maxTemperature, 31.0);
    service.close();
  });

  test('non-success responses produce a friendly WeatherException', () async {
    final service = WeatherService(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );

    await expectLater(
      service.fetchForecast(city),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('날씨 정보를'),
        ),
      ),
    );
    service.close();
  });
}
