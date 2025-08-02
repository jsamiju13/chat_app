import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chat_app/chat_screen.dart';
import 'package:chat_app/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _hasNavigated = false; // Prevenir navegaciones múltiples

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  void _initializeAuth() {
    // Escuchar cambios de autenticación (solo para futuras actualizaciones)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted && !_hasNavigated) {
        final session = data.session;
        _navigateBasedOnSession(session);
      }
    });

    // Verificación inicial después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasNavigated) {
        final currentSession = Supabase.instance.client.auth.currentSession;
        _navigateBasedOnSession(currentSession);
      }
    });
  }

  void _navigateBasedOnSession(Session? session) {
    if (_hasNavigated || !mounted) return;

    _hasNavigated = true;

    // Pequeño delay para evitar conflictos de navegación
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (session != null) {
        // Usuario logueado - ir al chat
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
          (route) => false, // Elimina todas las rutas anteriores
        );
      } else {
        // Usuario no logueado - ir al login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Elimina todas las rutas anteriores
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando...'),
          ],
        ),
      ),
    );
  }
}
