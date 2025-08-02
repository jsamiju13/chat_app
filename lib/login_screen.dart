import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chat_app/chat_screen.dart';

/// La pantalla de Login, la primera cara que ve el usuario.
///
/// Desde aquí puede entrar a su cuenta, crear una nueva, o simplemente
/// usar Google para no complicarse la vida. La pantalla es un camaleón:
/// cambia para mostrar lo que el usuario necesita en cada momento.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Necesitamos "escuchar" lo que el usuario teclea, para eso son estos controladores.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Esta es como la "llave maestra" de nuestro formulario.
  // La usaremos para preguntar: "Oye formulario, ¿está todo en orden?".
  final _formKey = GlobalKey<FormState>();

  // Dos banderitas para saber qué está pasando en la pantalla:
  bool _isLoading = false; // ¿Estamos esperando a que el servidor responda?
  bool _isSignUp = false;  // ¿El usuario quiere crear una cuenta nueva?

  // Cuando esta pantalla se va, hay que soltar los recursos que usa.
  // Es como apagar la luz al salir de una habitación.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Esta es la función gorda que se encarga del login y registro con email.
  Future<void> _signInWithEmail() async {
    // Primero lo primero: ¿el usuario rellenó bien los campos?
    // Si la "llave" del formulario nos dice que no, paramos aquí.
    if (!_formKey.currentState!.validate()) return;

    // ¡Acción! Ponemos la ruedita de "cargando" para que no se impacienten.
    setState(() => _isLoading = true);

    try {
      // ¿Es un nuevo usuario?
      if (_isSignUp) {
        // Pues a registrarlo en Supabase.
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Si todo fue bien, le dejamos un mensajito para que revise su email.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Genial! Revisa tu correo para activar la cuenta.')),
          );
        }
      } else {
        // No es nuevo, así que intentamos que inicie sesión.
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Si las credenciales son correctas, el sistema principal nos llevará al chat.
        // No hay que hacer nada más aquí. ¡Magia!
      }
    } on AuthException catch (error) {
      // ¡Ups! Algo salió mal con la autenticación.
      // Vamos a dar un mensaje de error un poco más amigable.
      if (mounted) {
        // Por defecto, usamos el mensaje de error que nos da Supabase.
        var errorMessage = 'Algo no ha ido bien. Inténtalo de nuevo.';
        
        // Pero para los errores más comunes, tenemos mensajes personalizados.
        final errorMsg = error.message.toLowerCase();
        if (errorMsg.contains('invalid login credentials')) {
          errorMessage = 'Ese correo y contraseña no nos suenan... ¿Seguro que son correctos?';
        } else if (errorMsg.contains('user already registered')) {
          errorMessage = '¡Parece que ya tienes una cuenta! Intenta iniciar sesión.';
        } else if (errorMsg.contains('email not confirmed')) {
          errorMessage = 'Casi listo. Tienes que confirmar tu email primero (mira en tu bandeja de spam).';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange[800]),
        );
      }
    } catch (error) {
      // Este es el "por si acaso" para cualquier otro error raro.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ha ocurrido un error inesperado. Disculpa las molestias.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Pase lo que pase, al final quitamos la ruedita de "cargando".
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// La vía rápida: iniciar sesión con Google.
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Le pasamos la pelota a Supabase para que se encargue del show con Google.
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Y le decimos a dónde tiene que volver cuando termine.
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      // El resto es automático. No tocamos nada.
    } catch (error) {
      // Si algo falla en el proceso con Google, se lo decimos al usuario.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hemos podido conectar con Google. ¿Quizás más tarde?')),
        );
      }
    } finally {
      // Y como siempre, limpiamos el estado de carga si algo falla.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // El título cambia según lo que el usuario esté haciendo.
        title: Text(_isSignUp ? "Crea tu cuenta" : "¡Hola de nuevo!"),
        centerTitle: true,
      ),
      body: Center( // Ponemos todo en el centro, que queda más ordenado.
        child: SingleChildScrollView( // Para que el teclado no nos fastidie la vista.
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Para que los botones se estiren.
              children: [
                // --- El campo para el email ---
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Tu correo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.alternate_email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => (val == null || !val.contains('@')) ? 'Necesitamos un correo de verdad :)' : null,
                ),
                const SizedBox(height: 16),

                // --- El campo para la contraseña ---
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Tu contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true, // Para que aparezcan puntitos y no la contraseña.
                  validator: (val) => (val == null || val.length < 6) ? 'La contraseña debe tener 6+ caracteres.' : null,
                ),
                const SizedBox(height: 24),

                // --- El botón de Entrar/Registrarse ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmail, // Si está cargando, no se puede pulsar.
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isSignUp ? '¡Vamos allá!' : 'Entrar'),
                ),
                
                // --- El texto para cambiar de idea ---
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(_isSignUp ? 'Mmm, mejor inicio sesión' : 'Soy nuevo por aquí'),
                ),
                const SizedBox(height: 16),

                // --- La línea decorativa con una "O" en medio ---
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('o si prefieres...')),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // --- El botón de Google ---
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata_outlined),
                  label: const Text('Entrar con Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
