import 'package:chat_app/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://sqxukbvitbxorflpaalp.supabase.co',
    anonKey: 'sb_publishable_01Bx-bnMpPzhYxj0xR7YNQ_rcxP3ez_',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}
