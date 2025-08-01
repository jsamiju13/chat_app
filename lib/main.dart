import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat_app/theme.dart';
import 'package:chat_app/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// new merge
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://sqxukbvitbxorflpaalp.supabase.co',
    anonKey: 'sb_publishable_01Bx-bnMpPzhYxj0xR7YNQ_rcxP3ez_',
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Chat App',
      theme: themeProvider.theme,
      home: const SplashScreen(),
    );
  }
}
