import 'package:flutter/material.dart';

import 'models/weather_models.dart';
import 'screens/weather_home_page.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1A73E8);

    return MaterialApp(
      title: 'WeatherApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamilyFallback: const ['Roboto', 'Noto Sans KR', 'sans-serif'],
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: seed,
          secondary: const Color(0xFFEA4335), // Google Red
          tertiary: const Color(0xFFFBBC05), // Google Yellow
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E3E9), width: 1.0),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFE0E3E9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFE0E3E9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: seed, width: 1.5),
          ),
        ),
      ),
      home: const WeatherHomePage(
        initialCity: City(
          name: 'Seoul',
          country: 'South Korea',
          admin1: 'Seoul',
          latitude: 37.566,
          longitude: 126.9784,
        ),
      ),
    );
  }
}
