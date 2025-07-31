import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chat_app/splash_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
    // El stream ahora obtiene todos los mensajes, la lógica de UI decidirá qué mostrar.
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id']).order('created_at');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetchBlockedUsers() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      final response = await Supabase.instance.client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', userId);
      final blockedUsers =
          (response as List).map((item) => item['blocked_id'] as String).toSet();
      if (mounted) {
        setState(() {
          _blockedUserIds = blockedUsers;
        });
      }
    } catch (e) {
      // Manejar error
    }
  }

  Future<void> _sendMessage() async {
    if (_textController.text.isEmpty) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('messages').insert({
        'content': _textController.text.trim(),
        'user_id': userId,
      });
      _textController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al enviar mensaje: $e')));
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  Future<void> _blockUser(String blockedId) async {
    final blockerId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client
          .from('blocked_users')
          .insert({'blocker_id': blockerId, 'blocked_id': blockedId});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario bloqueado.')));
      _fetchBlockedUsers(); // Actualizar la UI
    } catch (e) {
      // Manejar error
    }
  }

  // NUEVO: Función para desbloquear un usuario.
  Future<void> _unblockUser(String blockedId) async {
    final blockerId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .match({'blocker_id': blockerId, 'blocked_id': blockedId});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario desbloqueado.')));
      _fetchBlockedUsers(); // Actualizar la UI
    } catch (e) {
      // Manejar error
    }
  }

  void _showMessageOptions(String userId, bool isBlocked) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
                title: Text(isBlocked ? 'Desbloquear Usuario' : 'Bloquear Usuario'),
                onTap: () {
                  Navigator.of(context).pop();
                  if (isBlocked) {
                    _unblockUser(userId);
                  } else {
                    _blockUser(userId);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat en Tiempo Real'),
        actions: [IconButton(onPressed: _signOut, icon: const Icon(Icons.logout))],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                    final userId = message['user_id'];
                    final isMyMessage = userId == Supabase.instance.client.auth.currentUser!.id;
                    final isBlocked = _blockedUserIds.contains(userId);

                    // Widget para mensajes bloqueados
                    if (isBlocked && !isMyMessage) {
                      return ListTile(
                        leading: const Icon(Icons.block, color: Colors.grey),
                        title: const Text(
                          'Mensaje de un usuario bloqueado',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                        onLongPress: () => _showMessageOptions(userId, true),
                      );
                    }

                    // Widget para mensajes normales
                    return ListTile(
                      title: Text(message['content']),
                      subtitle: Text(_formatDate(message['created_at'])),
                      onLongPress: () {
                        if (!isMyMessage && userId != null) {
                          _showMessageOptions(userId, false);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(hintText: 'Escribe un mensaje...'),
                  onFieldSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
            ]),
          ),
        ],
      ),
    );
  }
}