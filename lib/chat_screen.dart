import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chat_app/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:chat_app/theme.dart';

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
    // The stream fetches all messages, UI will handle visibility
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at');
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
          (response as List)
              .map((item) => item['blocked_id'] as String)
              .toSet();
      if (mounted) {
        setState(() {
          _blockedUserIds = blockedUsers;
        });
      }
    } catch (e) {
      // Handle error
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar mensaje: $e')));
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario bloqueado.')));
      _fetchBlockedUsers();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _unblockUser(String blockedId) async {
    final blockerId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client.from('blocked_users').delete().match({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario desbloqueado.')));
      _fetchBlockedUsers();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _editMessage(int messageId, String newContent) async {
    if (newContent.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'content': newContent, 'is_edited': true})
          .eq('id', messageId);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al editar mensaje: $e')));
    }
  }

  void _showEditMessageDialog(Map<String, dynamic> message) {
    final editController = TextEditingController(text: message['content']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Mensaje'),
          content: TextField(controller: editController, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                _editMessage(message['id'], editController.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await Supabase.instance.client.from('messages').delete().match({
        'id': messageId,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mensaje eliminado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el mensaje: $e')),
        );
      }
    }
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    final isMyMessage =
        message['user_id'] == Supabase.instance.client.auth.currentUser!.id;
    final userId = message['user_id'] as String?;
    final isBlocked = userId != null && _blockedUserIds.contains(userId);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar Mensaje'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditMessageDialog(message);
                  },
                ),
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Eliminar Mensaje'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessage(message['id']);
                  },
                ),
              if (!isMyMessage && userId != null)
                ListTile(
                  leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
                  title: Text(
                    isBlocked ? 'Desbloquear Usuario' : 'Bloquear Usuario',
                  ),
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Fluteogram',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).nextTheme(),
            icon: const Icon(Icons.color_lens),
            tooltip: 'Cambiar tema',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión xd',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Mensajes
            Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '¡Algo salió mal! [${snapshot.error}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'Aún no hay mensajes.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.54),
                        ),
                      ),
                    );
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final messageUserId = message['user_id'];
                      final isMe = messageUserId == userId;
                      final isDeleted = message['is_deleted'] == true;
                      final isBlocked = _blockedUserIds.contains(messageUserId);

                      if (isDeleted) {
                        return const SizedBox.shrink();
                      }

                      if (isBlocked && !isMe) {
                        return GestureDetector(
                          onLongPress: () => _showMessageOptions(message),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blueGrey.shade700,
                                    child: const Icon(
                                      Icons.block,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: Text(
                                      'Mensaje de un usuario bloqueado',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(message),
                        child: Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment:
                                  isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe)
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    child: Icon(
                                      Icons.person,
                                      color:
                                          Theme.of(context).iconTheme.color ??
                                          Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                if (!isMe) const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isMe
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(
                                          isMe ? 18 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 4 : 18,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message['content'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_formatDate(message['created_at'])}${message['is_edited'] == true ? ' (editado)' : ''}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withOpacity(0.54),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isMe) const SizedBox(width: 8),
                                if (isMe)
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: Icon(
                                      Icons.person,
                                      color:
                                          Theme.of(context).iconTheme.color ??
                                          Colors.white,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Caja de texto flotante
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextFormField(
                          controller: _textController,
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .bodyMedium, // Use the current theme's bodyMedium style
                          decoration: InputDecoration(
                            // Make InputDecoration non-const
                            hintText: 'Escribe un mensaje...',
                            hintStyle: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color // Access color property
                                  ?.withOpacity(0.54),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onFieldSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send,
                          color:
                              Theme.of(context).iconTheme.color ?? Colors.white,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
