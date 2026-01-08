class ContactModel {
  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  ContactModel({
    required this.id,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Неизвестный',
      avatarUrl: json['avatarUrl'],
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen']) : null,
    );
  }
}
