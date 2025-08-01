import 'package:chat_app/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:chat_app/theme.dart';

// new merge
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vekvssibmvjhpgxlennz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZla3Zzc2libXZqaHBneGxlbm56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM3OTQ2NDYsImV4cCI6MjA2OTM3MDY0Nn0.MaM-jz8PQDxu_TDhlotxhPTPJhd7Yri9gR8sRZMGdpM',
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Chat App',
          theme: themeProvider.theme,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
