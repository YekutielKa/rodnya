import 'package:equatable/equatable.dart';

// ============================================================================
// MESSAGE MODEL
// ============================================================================

enum MessageType { text, image, video, audio, file, voice }
enum MessageStatus { sending, sent, delivered, read, failed }

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
  final int? duration; // for audio/video in seconds
  final MessageModel? replyTo;
  final List<String> readBy;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final Map<String, dynamic>? metadata;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.type = MessageType.text,
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
    this.isDeleted = false,
    this.metadata,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Handle sender as object or separate fields
    final sender = json['sender'];
    final senderId = sender?['id'] ?? json['senderId'] ?? json['sender_id'] ?? '';
    final senderName = sender?['name'] ?? json['senderName'] ?? json['sender_name'];
    final senderAvatar = sender?['avatarUrl'] ?? sender?['avatar_url'] ?? json['senderAvatar'];
    
    return MessageModel(
      id: json['id'] ?? json['_id'] ?? '',
      chatId: json['chatId'] ?? json['chat_id'] ?? '',
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      type: _parseMessageType(json['type']),
      content: json['content'],
      mediaUrl: json['mediaUrl'] ?? json['media_url'],
      thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail_url'],
      fileName: json['fileName'] ?? json['file_name'],
      fileSize: json['fileSize'] ?? json['file_size'],
      duration: json['duration'],
      replyTo: json['replyTo'] != null ? MessageModel.fromJson(json['replyTo']) : null,
      readBy: List<String>.from(json['readBy'] ?? json['read_by'] ?? []),
      status: _parseMessageStatus(json['status']),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      editedAt: json['editedAt'] != null || json['edited_at'] != null 
          ? _parseDateTime(json['editedAt'] ?? json['edited_at'])
          : null,
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'type': type.name,
    'content': content,
    'mediaUrl': mediaUrl,
    'thumbnailUrl': thumbnailUrl,
    'fileName': fileName,
    'fileSize': fileSize,
    'duration': duration,
    'replyTo': replyTo?.toJson(),
    'readBy': readBy,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'editedAt': editedAt?.toIso8601String(),
    'isDeleted': isDeleted,
    'metadata': metadata,
  };

  /// Create optimistic message for immediate UI update
  factory MessageModel.optimistic({
    required String tempId,
    required String chatId,
    required String senderId,
    String? senderName,
    MessageType type = MessageType.text,
    String? content,
    String? mediaUrl,
    MessageModel? replyTo,
  }) {
    return MessageModel(
      id: tempId,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      replyTo: replyTo,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? content,
    String? mediaUrl,
    String? thumbnailUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    MessageModel? replyTo,
    List<String>? readBy,
    MessageStatus? status,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      replyTo: replyTo ?? this.replyTo,
      readBy: readBy ?? this.readBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isMedia => type == MessageType.image || type == MessageType.video || 
                       type == MessageType.audio || type == MessageType.voice ||
                       type == MessageType.file;

  @override
  List<Object?> get props => [id, chatId, senderId, type, content, status, createdAt];

  static MessageType _parseMessageType(String? type) {
    switch (type?.toLowerCase()) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'voice': return MessageType.voice;
      case 'file': return MessageType.file;
      default: return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'sending': return MessageStatus.sending;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'failed': return MessageStatus.failed;
      default: return MessageStatus.sent;
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

// ============================================================================
// CHAT PARTICIPANT MODEL
// ============================================================================

class ChatParticipant extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final String role; // 'admin', 'member'
  final bool isOnline;
  final DateTime? lastSeen;

  const ChatParticipant({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.role = 'member',
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] ?? json['userId'] ?? json['user_id'] ?? '',
      name: json['name'] ?? json['displayName'] ?? 'Неизвестный',
      phone: json['phone'],
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      role: json['role'] ?? 'member',
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      lastSeen: json['lastSeen'] != null || json['last_seen'] != null
          ? DateTime.tryParse((json['lastSeen'] ?? json['last_seen']).toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'role': role,
    'isOnline': isOnline,
    'lastSeen': lastSeen?.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, name, role, isOnline];
}

// ============================================================================
// CHAT MODEL
// ============================================================================

enum ChatType { direct, group }

class ChatModel extends Equatable {
  final String id;
  final ChatType type;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final List<ChatParticipant> participants;
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
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    // Parse participants from either 'participants' or 'members'
    final participantsList = json['participants'] ?? json['members'] ?? [];
    
    return ChatModel(
      id: json['id'] ?? json['_id'] ?? '',
      type: (json['type'] ?? 'direct') == 'group' ? ChatType.group : ChatType.direct,
      name: json['name'],
      description: json['description'],
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      participants: (participantsList as List<dynamic>)
          .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastMessage: json['lastMessage'] != null || json['last_message'] != null
          ? MessageModel.fromJson(json['lastMessage'] ?? json['last_message'])
          : null,
      unreadCount: json['unreadCount'] ?? json['unread_count'] ?? 0,
      isMuted: json['isMuted'] ?? json['is_muted'] ?? false,
      isPinned: json['isPinned'] ?? json['is_pinned'] ?? false,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? json['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type == ChatType.group ? 'group' : 'direct',
    'name': name,
    'description': description,
    'avatarUrl': avatarUrl,
    'participants': participants.map((p) => p.toJson()).toList(),
    'lastMessage': lastMessage?.toJson(),
    'unreadCount': unreadCount,
    'isMuted': isMuted,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Get display name for chat
  /// For direct chats - returns other participant's name
  /// For group chats - returns group name
  String getDisplayName(String currentUserId) {
    if (type == ChatType.group) {
      return name ?? 'Группа';
    }
    
    if (participants.isEmpty) {
      return name ?? 'Чат';
    }
    
    final otherParticipant = participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => participants.first,
    );
    
    return otherParticipant.name.isNotEmpty 
        ? otherParticipant.name 
        : otherParticipant.phone ?? 'Неизвестный';
  }

  /// Get display avatar for chat
  String? getDisplayAvatar(String currentUserId) {
    if (type == ChatType.group) {
      return avatarUrl;
    }
    
    if (participants.isEmpty) {
      return avatarUrl;
    }
    
    final otherParticipant = participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => participants.first,
    );
    
    return otherParticipant.avatarUrl;
  }

  /// Get other participant for direct chats
  ChatParticipant? getOtherParticipant(String currentUserId) {
    if (type == ChatType.group || participants.isEmpty) {
      return null;
    }
    
    return participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => participants.first,
    );
  }

  /// Check if other user is online (for direct chats)
  bool isOtherOnline(String currentUserId) {
    final other = getOtherParticipant(currentUserId);
    return other?.isOnline ?? false;
  }

  ChatModel copyWith({
    String? id,
    ChatType? type,
    String? name,
    String? description,
    String? avatarUrl,
    List<ChatParticipant>? participants,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isMuted,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, type, name, participants, lastMessage, unreadCount, updatedAt];
}
