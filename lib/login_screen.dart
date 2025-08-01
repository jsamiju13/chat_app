import 'package:chat_app/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Iniciar sesión")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Widget de Supabase para la autenticación con correo y contraseña.
            SupaEmailAuth(
              onSignInComplete: (response) {
                // Redirige a la pantalla de chat si el inicio de sesión es exitoso.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              onSignUpComplete: (response) => {
                // Muestra un mensaje si el registro es exitoso.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Registro exitoso! Revisa tu correo para confirmar!",
                    ),
                  ),
                ),
              },
            ),
            const Divider(),
            // Botón personalizado para iniciar sesión con Google.
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Llama a la función de Supabase para iniciar sesión con un proveedor OAuth (en este caso, Google).
                  await Supabase.instance.client.auth.signInWithOAuth(
                    OAuthProvider.google,
                    // URL a la que Supabase redirigirá después de la autenticación.
                    // Debe estar configurada en el panel de Supabase.
                    redirectTo: 'io.supabase.flutterquickstart://login-callback/',
                  );
                } catch (e) {
                  // Muestra un error si algo sale mal durante el inicio de sesión.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al iniciar sesión con Google: $e'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Iniciar sesión con Google'),
            ),
          ],
        ),
      ),
    );
  }
}
