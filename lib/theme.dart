import 'package:flutter/material.dart';

class Estanque {
  static const verdeProfundo = Color(0xFF1B5E20);
  static const verdeRana = Color(0xFF4CAF50);
  static const verdeLima = Color(0xFF9CCC65);
  static const agua = Color(0xFF26A69A);
  static const aguaClara = Color(0xFFB2DFDB);
  static const barro = Color(0xFF6D4C41);
  static const nenufar = Color(0xFFF8BBD0);
  static const crema = Color(0xFFF1F8E9);
  static const amarillo = Color(0xFFFFC107);
  static const rojo = Color(0xFFE53935);
}

ThemeData temaEstanque() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Estanque.verdeRana,
    brightness: Brightness.light,
  ).copyWith(
    primary: Estanque.verdeProfundo,
    secondary: Estanque.agua,
    tertiary: Estanque.barro,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Estanque.crema,
    appBarTheme: const AppBarTheme(
      backgroundColor: Estanque.verdeProfundo,
      foregroundColor: Colors.white,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Estanque.agua,
      foregroundColor: Colors.white,
    ),
  );
}
