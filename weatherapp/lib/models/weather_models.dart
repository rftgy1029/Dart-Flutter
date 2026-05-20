class City {
  const City({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.admin1,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String? admin1;

  String get displayName {
    final parts = [
      name,
      if (admin1 != null && admin1!.isNotEmpty) admin1,
      country,
    ];
    return parts.join(', ');
  }

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String? ?? 'Unknown',
      country: json['country'] as String? ?? '',
      admin1: json['admin1'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class WeatherForecast {
  const WeatherForecast({
    required this.city,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.timezone,
  });

  final City city;
  final CurrentWeather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;
  final String timezone;
}

class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.weatherCode,
    required this.windSpeed,
    required this.isDay,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double precipitation;
  final int weatherCode;
  final double windSpeed;
  final bool isDay;
}

class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;
}

class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.maxTemperature,
    required this.minTemperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime date;
  final double maxTemperature;
  final double minTemperature;
  final int precipitationProbability;
  final int weatherCode;
}
