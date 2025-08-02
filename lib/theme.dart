import 'package:flutter/material.dart';

class AppThemes {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF181A20),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF23242B),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white70),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4F5D75),
      secondary: Color(0xFF23242B),
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F5F5),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color.fromARGB(255, 7, 209, 182),
      secondary: Color.fromARGB(255, 240, 240, 240),
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black87)),
  );

  static final ThemeData pinkPurpleTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFE0FF), // fondo personalizado
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(
        0xFFFFA8D9,
      ), // mismo color que mensajes de otros usuarios
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFEC4690), // mensaje del usuario activo
      secondary: Color(0xFFFFA8D9), // mensaje de otros usuarios
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      // Usar blanco para los mensajes del usuario activo
      bodyLarge: TextStyle(color: Colors.white),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  int _themeIndex = 0;
  final List<ThemeData> _themes = [
    AppThemes.darkTheme,
    AppThemes.lightTheme,
    AppThemes.pinkPurpleTheme,
  ];

  ThemeData get theme => _themes[_themeIndex];
  int get themeIndex => _themeIndex;

  void nextTheme() {
    _themeIndex = (_themeIndex + 1) % _themes.length;
    notifyListeners();
  }
}