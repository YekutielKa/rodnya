import 'package:equatable/equatable.dart';

enum ChatType { direct, group }
enum MessageType { text, image, video, voice, audio, file }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatModel extends Equatable {
  final String id;
  final ChatType type;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final List<ChatMember> participants;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['createdAt'] ?? json['created_at'];
    final updatedAtStr = json['updatedAt'] ?? json['updated_at'] ?? createdAtStr;
    
    List<ChatMember> participantsList = [];
    if (json['participants'] != null) {
      participantsList = (json['participants'] as List<dynamic>)
          .map((e) => ChatMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['otherUser'] != null) {
      final ou = json['otherUser'] as Map<String, dynamic>;
      participantsList = [
        ChatMember(
          id: ou['id'] as String? ?? '',
          chatId: json['id'] as String? ?? '',
          userId: ou['id'] as String? ?? '',
          name: ou['name'] as String?,
          avatarUrl: ou['avatarUrl'] as String? ?? ou['avatar_url'] as String?,
          isOnline: ou['isOnline'] as bool? ?? ou['is_online'] as bool? ?? false,
        ),
      ];
    }

    MessageModel? lastMsg;
    final lm = json['lastMessage'] ?? json['last_message'];
    if (lm != null) lastMsg = MessageModel.fromJson(lm as Map<String, dynamic>);

    return ChatModel(
      id: json['id'] as String,
      type: json['type'] == 'group' ? ChatType.group : ChatType.direct,
      name: json['name'] as String?,
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      participants: participantsList,
      lastMessage: lastMsg,
      unreadCount: json['unreadCount'] as int? ?? json['unread_count'] as int? ?? 0,
      isMuted: json['isMuted'] as bool? ?? json['is_muted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(createdAtStr as String),
      updatedAt: DateTime.parse(updatedAtStr as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type == ChatType.group ? 'group' : 'direct',
    'name': name,
    'description': description,
    'avatar_url': avatarUrl,
    'participants': participants.map((e) => e.toJson()).toList(),
    'last_message': lastMessage?.toJson(),
    'unread_count': unreadCount,
    'is_muted': isMuted,
    'is_pinned': isPinned,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ChatModel copyWith({String? name, String? description, String? avatarUrl,
      List<ChatMember>? participants, MessageModel? lastMessage, int? unreadCount,
      bool? isMuted, bool? isPinned, DateTime? updatedAt}) {
    return ChatModel(id: id, type: type, name: name ?? this.name,
      description: description ?? this.description, avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants ?? this.participants, lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount, isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt);
  }

  String getDisplayName(String currentUserId) {
    if (type == ChatType.group) return name ?? 'Группа';
    final other = getOtherParticipant(currentUserId);
    return other?.name ?? name ?? 'Чат';
  }

  String? getDisplayAvatar(String currentUserId) {
    if (type == ChatType.group) return avatarUrl;
    return getOtherParticipant(currentUserId)?.avatarUrl ?? avatarUrl;
  }

  ChatMember? getOtherParticipant(String currentUserId) {
    if (type != ChatType.direct) return null;
    try { return participants.firstWhere((p) => p.userId != currentUserId); }
    catch (_) { return participants.isNotEmpty ? participants.first : null; }
  }

  bool isOtherOnline(String currentUserId) => getOtherParticipant(currentUserId)?.isOnline ?? false;

  @override
  List<Object?> get props => [id, type, name, avatarUrl, participants, lastMessage, unreadCount, isMuted, isPinned];
}

class ChatMember extends Equatable {
  final String id;
  final String chatId;
  final String userId;
  final String? name;
  final String? avatarUrl;
  final String role;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? joinedAt;

  const ChatMember({
    required this.id,
    required this.chatId,
    required this.userId,
    this.name,
    this.avatarUrl,
    this.role = 'member',
    this.isOnline = false,
    this.lastSeen,
    this.joinedAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    final ls = json['lastSeen'] ?? json['last_seen'];
    final ja = json['joinedAt'] ?? json['joined_at'];
    return ChatMember(
      id: json['id'] as String? ?? '',
      chatId: json['chatId'] as String? ?? json['chat_id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
      isOnline: json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
      lastSeen: ls != null ? DateTime.parse(ls as String) : null,
      joinedAt: ja != null ? DateTime.parse(ja as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'chat_id': chatId, 'user_id': userId, 'name': name,
    'avatar_url': avatarUrl, 'role': role, 'is_online': isOnline,
    'last_seen': lastSeen?.toIso8601String(), 'joined_at': joinedAt?.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, userId, name, isOnline];
}

class MessageModel extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final int? duration;
  final MessageModel? replyTo;
  final List<String> readBy;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isEdited;
  final bool isDeleted;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.type,
    this.content,
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.replyTo,
    this.readBy = const [],
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.editedAt,
    this.isEdited = false,
    this.isDeleted = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final ca = json['createdAt'] ?? json['created_at'];
    final ea = json['editedAt'] ?? json['edited_at'];
    final rt = json['replyTo'] ?? json['reply_to'];
    final rb = json['readBy'] ?? json['read_by'];
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chatId'] as String? ?? json['chat_id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? json['sender_id'] as String? ?? '',
      senderName: json['senderName'] as String? ?? json['sender_name'] as String?,
      senderAvatar: json['senderAvatar'] as String? ?? json['sender_avatar'] as String?,
      type: _parseMessageType(json['type'] as String? ?? 'text'),
      content: json['content'] as String?,
      mediaUrl: json['mediaUrl'] as String? ?? json['media_url'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? json['thumbnail_url'] as String?,
      fileName: json['fileName'] as String? ?? json['file_name'] as String?,
      fileSize: json['fileSize'] as int? ?? json['file_size'] as int?,
      duration: json['duration'] as int?,
      replyTo: rt != null ? MessageModel.fromJson(rt as Map<String, dynamic>) : null,
      readBy: (rb as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      status: _parseMessageStatus(json['status'] as String? ?? 'sent'),
      createdAt: DateTime.parse(ca as String),
      editedAt: ea != null ? DateTime.parse(ea as String) : null,
      isEdited: json['isEdited'] as bool? ?? json['is_edited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'chat_id': chatId, 'sender_id': senderId, 'sender_name': senderName,
    'sender_avatar': senderAvatar, 'type': type.name, 'content': content,
    'media_url': mediaUrl, 'thumbnail_url': thumbnailUrl, 'file_name': fileName,
    'file_size': fileSize, 'duration': duration, 'reply_to': replyTo?.toJson(),
    'read_by': readBy, 'status': status.name, 'created_at': createdAt.toIso8601String(),
    'edited_at': editedAt?.toIso8601String(), 'is_edited': isEdited, 'is_deleted': isDeleted,
  };

  MessageModel copyWith({String? content, String? mediaUrl, String? thumbnailUrl,
      MessageStatus? status, List<String>? readBy, bool? isEdited, bool? isDeleted, DateTime? editedAt}) {
    return MessageModel(id: id, chatId: chatId, senderId: senderId, senderName: senderName,
      senderAvatar: senderAvatar, type: type, content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl, thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName, fileSize: fileSize, duration: duration, replyTo: replyTo,
      readBy: readBy ?? this.readBy, status: status ?? this.status, createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt, isEdited: isEdited ?? this.isEdited, isDeleted: isDeleted ?? this.isDeleted);
  }

  String getPreviewText() {
    if (isDeleted) return 'Сообщение удалено';
    switch (type) {
      case MessageType.text: return content ?? '';
      case MessageType.image: return '📷 Фото';
      case MessageType.video: return '🎬 Видео';
      case MessageType.voice: return '🎤 Голосовое сообщение';
      case MessageType.audio: return '🎵 Аудио';
      case MessageType.file: return '📎 ${fileName ?? "Файл"}';
    }
  }

  static MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'voice': return MessageType.voice;
      case 'audio': return MessageType.audio;
      case 'file': return MessageType.file;
      default: return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(String status) {
    switch (status.toLowerCase()) {
      case 'sending': return MessageStatus.sending;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'failed': return MessageStatus.failed;
      default: return MessageStatus.sent;
    }
  }

  @override
  List<Object?> get props => [id, status, isDeleted, readBy, isEdited];
}
