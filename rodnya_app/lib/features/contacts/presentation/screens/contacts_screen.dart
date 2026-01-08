import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/contact_model.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactModel> _contacts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiClient = ApiClient();
      final response = await apiClient.get('/users');
      
      if (response.data['success'] == true && response.data['data'] != null) {
        final users = response.data['data'] as List<dynamic>;
        setState(() {
          _contacts = users.map((u) => ContactModel.fromJson(u)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _contacts = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openChat(ContactModel contact) async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post('/chats/direct', data: {
        'userId': contact.userId,
      });

      if (response.data['success'] == true && response.data['data'] != null) {
        final chatId = response.data['data']['chatId'];
        if (mounted) {
          context.push('/chat/$chatId');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'] ?? 'Ошибка открытия чата')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _startCall(ContactModel contact, bool isVideo) async {
    try {
      final apiClient = ApiClient();
      
      // First create/get chat
      final chatResponse = await apiClient.post('/chats/direct', data: {
        'userId': contact.userId,
      });

      if (chatResponse.data['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка создания чата')),
          );
        }
        return;
      }

      final chatId = chatResponse.data['data']['chatId'];

      // Then initiate call
      final callResponse = await apiClient.post('/calls/initiate', data: {
        'chatId': chatId,
        'type': isVideo ? 'video' : 'audio',
      });

      if (callResponse.data['success'] == true && callResponse.data['data'] != null) {
        final callId = callResponse.data['data']['callId'];
        if (mounted) {
          context.push('/call/$callId', extra: {
            'isVideo': isVideo,
            'isIncoming': false,
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(callResponse.data['message'] ?? 'Ошибка звонка')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _showContactOptions(ContactModel contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Написать сообщение'),
              onTap: () {
                Navigator.pop(ctx);
                _openChat(contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Аудиозвонок'),
              onTap: () {
                Navigator.pop(ctx);
                _startCall(contact, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Видеозвонок'),
              onTap: () {
                Navigator.pop(ctx);
                _startCall(contact, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getLastSeenText(ContactModel contact) {
    if (contact.isOnline) return 'онлайн';
    if (contact.lastSeen == null) return 'был(а) недавно';
    
    final diff = DateTime.now().difference(contact.lastSeen!);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч назад';
    return 'был(а) ${diff.inDays} дн назад';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка загрузки', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadContacts,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _contacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Пока нет контактов', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      child: ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: contact.avatarUrl != null
                                  ? NetworkImage(contact.avatarUrl!)
                                  : null,
                              child: contact.avatarUrl == null
                                  ? Text(
                                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '+',
                                      style: const TextStyle(color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            title: Text(contact.name),
                            subtitle: Text(
                              _getLastSeenText(contact),
                              style: TextStyle(
                                color: contact.isOnline ? AppColors.success : AppColors.grey400,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call, color: AppColors.primary),
                                  onPressed: () => _startCall(contact, false),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.videocam, color: AppColors.primary),
                                  onPressed: () => _startCall(contact, true),
                                ),
                              ],
                            ),
                            onTap: () => _openChat(contact),
                            onLongPress: () => _showContactOptions(contact),
                          );
                        },
                      ),
                    ),
    );
  }
}
