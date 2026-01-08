import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../../../core/api/api_client.dart';

class CallRecord {
  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final String type; // 'incoming', 'outgoing', 'missed'
  final String callType; // 'audio', 'video'
  final DateTime createdAt;
  final int? duration;

  CallRecord({
    required this.id,
    required this.odanya userId,
    required this.name,
    this.avatarUrl,
    required this.type,
    required this.callType,
    required this.createdAt,
    this.duration,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['otherUserId'] ?? '',
      name: json['name'] ?? json['otherUserName'] ?? 'Неизвестный',
      avatarUrl: json['avatarUrl'],
      type: json['type'] ?? 'outgoing',
      callType: json['callType'] ?? 'audio',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      duration: json['duration'],
    );
  }
}

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<CallRecord> _calls = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiClient = ApiClient();
      final response = await apiClient.get('/calls/history');
      
      if (response.data['success'] == true && response.data['data'] != null) {
        final calls = response.data['data'] as List<dynamic>;
        setState(() {
          _calls = calls.map((c) => CallRecord.fromJson(c)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _calls = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _calls = [];
        _isLoading = false;
        // Не показываем ошибку - просто пустой список
      });
    }
  }

  String _getCallTimeText(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${time.day}.${time.month}.${time.year}';
  }

  IconData _getCallIcon(CallRecord call) {
    if (call.type == 'missed') {
      return Icons.call_missed;
    } else if (call.type == 'incoming') {
      return Icons.call_received;
    } else {
      return Icons.call_made;
    }
  }

  Color _getCallIconColor(CallRecord call) {
    if (call.type == 'missed') {
      return Colors.red;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Звонки'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет звонков',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'История звонков появится здесь',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCalls,
                  child: ListView.builder(
                    itemCount: _calls.length,
                    itemBuilder: (context, index) {
                      final call = _calls[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: call.avatarUrl != null
                              ? NetworkImage(call.avatarUrl!)
                              : null,
                          child: call.avatarUrl == null
                              ? Text(
                                  call.name.isNotEmpty ? call.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary),
                                )
                              : null,
                        ),
                        title: Text(
                          call.name,
                          style: TextStyle(
                            color: call.type == 'missed' ? Colors.red : null,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              _getCallIcon(call),
                              size: 16,
                              color: _getCallIconColor(call),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              call.type == 'missed'
                                  ? 'Пропущенный'
                                  : call.type == 'incoming'
                                      ? 'Входящий'
                                      : 'Исходящий',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getCallTimeText(call.createdAt),
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            call.callType == 'video' ? Icons.videocam : Icons.phone,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            // TODO: Start call
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
