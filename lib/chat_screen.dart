import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chat_app/splash_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
// Asegura que el registro de typing_status exista para el usuario
Future<void> _ensureTypingStatusExists() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  try {
    // Intenta obtener el registro
    final response = await Supabase.instance.client
        .from('typing_status')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null || response.isEmpty) {
      // Si no existe, lo crea
      await Supabase.instance.client.from('typing_status').insert({
        'user_id': userId,
        'is_typing': false,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  } catch (_) {}
}
// Función para obtener el perfil de usuario desde Supabase
Future<Map<String, dynamic>> getUserProfile(String userId) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select('username, avatar_url')
      .eq('id', userId)
      .maybeSingle();
  if (response == null || response.isEmpty) {
    return {
      'username': 'Usuario desconocido',
      'avatar_url': null,
    };
  }
  return {
    'username': response['username'] ?? 'Usuario desconocido',
    'avatar_url': response['avatar_url'],
  };
}

// Verifica si el usuario tiene perfil y lo solicita si no existe
Future<void> _checkAndAskProfile(BuildContext context) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  final profile = await getUserProfile(userId);
  if (profile['username'] == 'Usuario desconocido' || profile['username'] == null) {
    final completed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(userId: userId),
      ),
    );
    if (completed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Perfil actualizado!')),
      );
    }
  }
}
// Pantalla para completar el perfil
class CompleteProfileScreen extends StatefulWidget {
  final String userId;
  const CompleteProfileScreen({required this.userId, super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _usernameController = TextEditingController();
  final _avatarController = TextEditingController();
  bool _loading = false;
  File? _selectedImage;
  String? _uploadedImageUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final fileName = 'avatars/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.png';
    final bytes = await imageFile.readAsBytes();
    final response = await Supabase.instance.client.storage
        .from('avatars')
        .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
    // Si response está vacío, hubo error
    if (response.isEmpty) {
      return null;
    }
    // Obtener la URL pública
    final publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
    return publicUrl;
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    String avatarUrl = _avatarController.text.trim();
    try {
      // En web, no se puede subir archivo local, solo usar URL
      if (_selectedImage != null && !kIsWeb) {
        final uploadedUrl = await _uploadImage(_selectedImage!);
        if (uploadedUrl != null) {
          avatarUrl = uploadedUrl;
          setState(() {
            _uploadedImageUrl = uploadedUrl;
          });
        }
      }
      await Supabase.instance.client.from('profiles').upsert({
        'id': widget.userId,
        'username': _usernameController.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() => _loading = false);
      // Mostrar la URL generada como confirmación
      if (_uploadedImageUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL de avatar generada: $_uploadedImageUrl')),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar perfil: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Nombre de usuario'),
            ),
            TextField(
              controller: _avatarController,
              decoration: const InputDecoration(labelText: 'URL de avatar (opcional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Seleccionar imagen'),
                  onPressed: _loading ? null : _pickImage,
                ),
                if (_selectedImage != null && !kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.file(_selectedImage!),
                    ),
                  ),
                if (_uploadedImageUrl != null && kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(_uploadedImageUrl!),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading ? const CircularProgressIndicator() : const Text('Guardar'),
            ),
            if (_uploadedImageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Imagen subida correctamente'),
              ),
          ],
        ),
      ),
    );
  }
}



class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _messagesStream = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at');

  // Stream para el indicador de escritura
  late final Stream<List<Map<String, dynamic>>> _typingStream;
  // String? _typingUsername; // Eliminada porque no se usa
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _typingStream = Supabase.instance.client
        .from('typing_status')
        .stream(primaryKey: ['id'])
        .eq('is_typing', true);
    _textController.addListener(_handleTyping);
    // Asegura el registro typing_status al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTypingStatusExists());
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTyping);
    _textController.dispose();
    super.dispose();
  }

  // Actualiza el estado de escritura del usuario
  Future<void> _updateTypingStatus(bool typing) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('typing_status').upsert({
        'user_id': userId,
        'is_typing': typing,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // Detecta si el usuario está escribiendo
  void _handleTyping() {
    final isNowTyping = _textController.text.isNotEmpty;
    if (_isTyping != isNowTyping) {
      _isTyping = isNowTyping;
      _updateTypingStatus(_isTyping);
    }
  }

  // Elimina el segundo dispose duplicado

  Future<void> _sendMessage() async {
    if (_textController.text.isEmpty) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('messages').insert({
        'content': _textController.text.trim(),
        'user_id': userId,
      });
      if (!mounted) return; // <-- Agrega esto
      _textController.clear();
    } catch (e) {
      if (!mounted) return; // <-- Agrega esto
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar mensaje: $e')));
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final hourMinute =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) {
      return hourMinute;
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$hourMinute $day/$month/$year';
    }
  }

  Map<String, Map<String, dynamic>> _profileCache = {};

  @override
  Widget build(BuildContext context) {
    // Verifica perfil al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndAskProfile(context));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat en Tiempo Real'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Probar perfil',
            onPressed: () async {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId != null) {
                final profile = await getUserProfile(userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nombre: ${profile['username']}, Avatar: ${profile['avatar_url']}')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No hay usuario autenticado.')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de escritura
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _typingStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                final typingUsers = snapshot.data!
                    .where((row) => row['user_id'] != userId)
                    .toList();
                if (typingUsers.isNotEmpty) {
                  // Solo muestra el primero (puedes mostrar todos si quieres)
                  final typingUserId = typingUsers[0]['user_id'] as String;
                  return FutureBuilder<Map<String, dynamic>>(
                    future: getUserProfile(typingUserId),
                    builder: (context, profileSnapshot) {
                      final username = profileSnapshot.data != null
                          ? profileSnapshot.data!['username'] ?? 'Alguien'
                          : 'Alguien';
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '💬 $username está escribiendo...',
                          style: const TextStyle(color: Colors.deepPurple, fontStyle: FontStyle.italic),
                        ),
                      );
                    },
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('¡Algo salió mal! ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aún no hay mensajes.'));
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final userId = message['user_id'] as String?;
                    return FutureBuilder<Map<String, dynamic>>(
                      future: () async {
                        if (userId == null) {
                          return {'username': 'Usuario desconocido', 'avatar_url': null};
                        }
                        if (_profileCache.containsKey(userId)) {
                          return _profileCache[userId]!;
                        }
                        final profile = await getUserProfile(userId);
                        _profileCache[userId] = profile;
                        return profile;
                      }(),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data ?? {'username': '...', 'avatar_url': null};
                        bool isValidAvatarUrl(String? url) {
                          if (url == null) return false;
                          final uri = Uri.tryParse(url);
                          return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
                        }
                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) {
                                  final isCurrentUser = userId == Supabase.instance.client.auth.currentUser?.id;
                                  TextEditingController nameController = TextEditingController(text: profile['username']);
                                  TextEditingController avatarController = TextEditingController(text: profile['avatar_url'] ?? '');
                                  File? selectedImage;
                                  bool loading = false;
                                  String? errorMsg;
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return Dialog(
                                        backgroundColor: Colors.black87,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Align(
                                                alignment: Alignment.topRight,
                                                child: IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.white),
                                                  onPressed: () => Navigator.of(context).pop(),
                                                ),
                                              ),
                                              isValidAvatarUrl(profile['avatar_url'])
                                                  ? Center(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Image.network(
                                                          profile['avatar_url'],
                                                          width: 220,
                                                          height: 220,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(Icons.person, size: 120, color: Colors.white),
                                              const SizedBox(height: 16),
                                              Text(
                                                profile['username'],
                                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              if (isCurrentUser) ...[
                                                const SizedBox(height: 18),
                                                TextField(
                                                  controller: nameController,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: InputDecoration(
                                                    labelText: 'Editar nombre',
                                                    labelStyle: const TextStyle(color: Colors.white70),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: Colors.white24),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                TextField(
                                                  controller: avatarController,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: InputDecoration(
                                                    labelText: 'Editar URL de avatar',
                                                    labelStyle: const TextStyle(color: Colors.white70),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: Colors.white24),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.image),
                                                  label: const Text('Seleccionar imagen'),
                                                  onPressed: loading ? null : () async {
                                                    if (kIsWeb) return;
                                                    final picker = ImagePicker();
                                                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                                                    if (pickedFile != null) {
                                                      setState(() {
                                                        selectedImage = File(pickedFile.path);
                                                      });
                                                    }
                                                  },
                                                ),
                                                if (selectedImage != null && !kIsWeb)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: SizedBox(
                                                      width: 80,
                                                      height: 80,
                                                      child: Image.file(selectedImage!),
                                                    ),
                                                  ),
                                                if (errorMsg != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent)),
                                                  ),
                                                const SizedBox(height: 16),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                                                  onPressed: loading
                                                      ? null
                                                      : () async {
                                                          setState(() { loading = true; errorMsg = null; });
                                                          String newAvatarUrl = avatarController.text.trim();
                                                          try {
                                                            if (selectedImage != null && !kIsWeb) {
                                                              final fileName = 'avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}.png';
                                                              final bytes = await selectedImage!.readAsBytes();
                                                              final response = await Supabase.instance.client.storage
                                                                  .from('avatars')
                                                                  .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
                                                              if (response.isNotEmpty) {
                                                                newAvatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
                                                              }
                                                            }
                                                            await Supabase.instance.client.from('profiles').upsert({
                                                              'id': userId,
                                                              'username': nameController.text.trim(),
                                                              'avatar_url': newAvatarUrl,
                                                              'updated_at': DateTime.now().toIso8601String(),
                                                            });
                                                            if (!mounted) return;
                                                            setState(() { loading = false; });
                                                            // Limpiar el cache y refrescar la pantalla principal
                                                            Navigator.of(context).pop();
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Perfil actualizado')),);
                                                            // Eliminar el perfil cacheado y refrescar el chat (nombre y avatar)
                                                            if (context.mounted) {
                                                              final chatState = context.findAncestorStateOfType<_ChatScreenState>();
                                                              if (chatState != null) {
                                                                chatState.setState(() {
                                                                  chatState._profileCache.remove(userId);
                                                                  // Fuerza refresco de todos los mensajes
                                                                });
                                                              }
                                                            }
                                                          } catch (e) {
                                                            setState(() { loading = false; errorMsg = 'Error: $e'; });
                                                          }
                                                        },
                                                  child: loading ? const CircularProgressIndicator() : const Text('Guardar cambios'),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: isValidAvatarUrl(profile['avatar_url'])
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(profile['avatar_url']),
                                  )
                                : const CircleAvatar(child: Icon(Icons.person)),
                          ),
                          title: Text(profile['username']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message['content']),
                              Text(_formatDate(message['created_at'])),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
