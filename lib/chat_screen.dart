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
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((messages) {
      return messages
          .where((message) =>
              message['user_id'] != null &&
              !_blockedUserIds.contains(message['user_id']))
          .toList();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetchBlockedUsers() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('blocked_users')
        .select('blocked_id')
        .eq('blocker_id', userId);
    final blockedUsers =
        (response as List).map((item) => item['blocked_id'] as String).toSet();
    setState(() {
      _blockedUserIds = blockedUsers;
    });
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

  Future<void> _blockUser(String blockedId) async {
    final blockerId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client.from('blocked_users').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario bloqueado.')),
      );
      _fetchBlockedUsers(); // Refresh the blocked users list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al bloquear usuario: $e')),
      );
    }
  }

  void _showBlockMenu(String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Bloquear Usuario'),
                onTap: () {
                  Navigator.of(context).pop();
                  _blockUser(userId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat en Tiempo Real'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Column(
        children: [
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
                    final userId = message['user_id'];
                    final isMyMessage = userId == Supabase.instance.client.auth.currentUser!.id;

                    return ListTile(
                      title: Text(message['content']),
                      subtitle: Text(_formatDate(message['created_at'])),
                      onLongPress: () {
                        if (!isMyMessage && userId != null) {
                          _showBlockMenu(userId);
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
