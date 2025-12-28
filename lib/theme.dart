import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF6C63FF); // purple-ish seed

  static final ThemeData lightTheme = ThemeData(
    colorScheme:
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    textTheme: Typography.material2021().black,
  );
}
