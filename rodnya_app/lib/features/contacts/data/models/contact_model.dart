class ContactModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  ContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String?;
    final phone = json['phone'] as String? ?? '';
    final displayName = (rawName != null && rawName.isNotEmpty) ? rawName : phone;
    
    return ContactModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['id'] ?? '',
      name: displayName,
      phone: phone,
      avatarUrl: json['avatarUrl'],
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
    );
  }
}
