import 'dart:async';
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

  // Estado para el rate limiting
  bool _isRateLimited = false;
  int _penaltySecondsRemaining = 0;
  Timer? _penaltyTimer;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id']).order('created_at');
  }

  @override
  void dispose() {
    _textController.dispose();
    _penaltyTimer?.cancel(); // Asegurarse de cancelar el timer
    super.dispose();
  }

  void _startRateLimitPenalty() {
    if (_isRateLimited) return; // Si ya está en penalización, no hacer nada

    setState(() {
      _isRateLimited = true;
      _penaltySecondsRemaining = 15;
    });

    _penaltyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_penaltySecondsRemaining > 1) {
        setState(() {
          _penaltySecondsRemaining--;
        });
      } else {
        setState(() {
          _isRateLimited = false;
          _penaltySecondsRemaining = 0;
        });
        timer.cancel();
      }
    });
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
    if (_textController.text.isEmpty || _isRateLimited) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('messages').insert({
        'content': _textController.text.trim(),
        'user_id': userId,
      });
      _textController.clear();
    } on PostgrestException catch (e) {
      if (e.code == '429') {
        _startRateLimitPenalty();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: ${e.message}')),
        );
      }
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
      _fetchBlockedUsers();
    } catch (e) {
      // Manejar error
    }
  }

  Future<void> _unblockUser(String blockedId) async {
    final blockerId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .match({'blocker_id': blockerId, 'blocked_id': blockedId});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario desbloqueado.')));
      _fetchBlockedUsers();
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
          // Widget de penalización
          if (_isRateLimited)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Colors.red.withOpacity(0.9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Demasiado rápido. Puedes volver a intentarlo en $_penaltySecondsRemaining segundos.',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  enabled: !_isRateLimited, // Desactivar si está penalizado
                  decoration: InputDecoration(
                    hintText: _isRateLimited ? '...' : 'Escribe un mensaje...',
                  ),
                  onFieldSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isRateLimited ? null : _sendMessage, // Desactivar si está penalizado
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
