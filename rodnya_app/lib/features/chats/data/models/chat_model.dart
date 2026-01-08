class ChatModel {
  final String id;
  final String type; // 'direct' or 'group'
  final String? name;
  final String? avatarUrl;
  final List<ChatParticipant> participants;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] ?? json['_id'] ?? '',
      type: json['type'] ?? 'direct',
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => ChatParticipant.fromJson(p))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  String getDisplayName(String currentUserId) {
    if (type == 'group') {
      return name ?? 'Группа';
    }
    final otherParticipant = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : ChatParticipant(userId: '', name: 'Неизвестный'),
    );
    return otherParticipant.name;
  }

  String? getDisplayAvatar(String currentUserId) {
    if (type == 'group') {
      return avatarUrl;
    }
    final otherParticipant = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : ChatParticipant(userId: '', name: ''),
    );
    return otherParticipant.avatarUrl;
  }
}

class ChatParticipant {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool isOnline;

  ChatParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.role = 'member',
    this.isOnline = false,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json;
    return ChatParticipant(
      userId: user['id'] ?? user['_id'] ?? json['userId'] ?? '',
      name: user['name'] ?? 'Неизвестный',
      avatarUrl: user['avatarUrl'],
      role: json['role'] ?? 'member',
      isOnline: user['isOnline'] ?? false,
    );
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String type; // 'text', 'image', 'video', 'audio', 'file'
  final String? content;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final MessageModel? replyTo;
  final List<String> readBy;
  final DateTime createdAt;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.type,
    this.content,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.replyTo,
    this.readBy = const [],
    required this.createdAt,
    this.isDeleted = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? json['_id'] ?? '',
      chatId: json['chatId'] ?? json['chat'] ?? '',
      senderId: json['senderId'] ?? json['sender']?['id'] ?? json['sender']?['_id'] ?? '',
      senderName: json['sender']?['name'] ?? json['senderName'],
      type: json['type'] ?? 'text',
      content: json['content'],
      mediaUrl: json['mediaUrl'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      duration: json['duration'],
      replyTo: json['replyTo'] != null ? MessageModel.fromJson(json['replyTo']) : null,
      readBy: List<String>.from(json['readBy'] ?? []),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'type': type,
      'content': content,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration,
      'replyTo': replyTo?.id,
    };
  }

  String getPreviewText() {
    if (isDeleted) return 'Сообщение удалено';
    switch (type) {
      case 'image':
        return '📷 Фото';
      case 'video':
        return '🎬 Видео';
      case 'audio':
        return '🎵 Аудио';
      case 'voice':
        return '🎤 Голосовое сообщение';
      case 'file':
        return '📎 ${fileName ?? "Файл"}';
      default:
        return content ?? '';
    }
  }
}
