import 'package:flutter_test/flutter_test.dart';
import 'package:weatherapp/models/weather_models.dart';

void main() {
  group('City', () {
    test('parses an Open-Meteo result and creates a display name', () {
      final city = City.fromJson({
        'name': 'Seoul',
        'country': 'South Korea',
        'admin1': 'Seoul',
        'latitude': 37.566,
        'longitude': 126.9784,
      });

      expect(city.displayName, 'Seoul, Seoul, South Korea');
      expect(city.latitude, 37.566);
      expect(city.longitude, 126.9784);
    });

    test('round-trips through JSON used by saved city preferences', () {
      const original = City(
        name: 'Busan',
        country: 'South Korea',
        admin1: 'Busan',
        latitude: 35.1796,
        longitude: 129.0756,
      );

      final restored = City.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.country, original.country);
      expect(restored.admin1, original.admin1);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
    });
  });
}
