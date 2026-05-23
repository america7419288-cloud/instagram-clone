class CommunityChannel {
  final String id;
  final String communityId;
  final String name;
  final String description;
  final String type; // 'general' | 'announcement' | 'chat' | 'media' | 'event'
  final int order;
  final bool isDefault;
  final List<String> allowedRoles;
  final DateTime createdAt;

  CommunityChannel({
    required this.id,
    required this.communityId,
    required this.name,
    required this.description,
    required this.type,
    required this.order,
    required this.isDefault,
    required this.allowedRoles,
    required this.createdAt,
  });

  factory CommunityChannel.fromJson(Map<String, dynamic> json) {
    return CommunityChannel(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'general',
      order: json['order'] ?? 0,
      isDefault: json['is_default'] ?? false,
      allowedRoles: json['allowed_roles'] != null ? List<String>.from(json['allowed_roles']) : const [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'community_id': communityId,
      'name': name,
      'description': description,
      'type': type,
      'order': order,
      'is_default': isDefault,
      'allowed_roles': allowedRoles,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
