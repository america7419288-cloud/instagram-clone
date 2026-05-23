class CommunityRule {
  final String id;
  final String communityId;
  final String title;
  final String description;
  final int order;
  final DateTime createdAt;

  CommunityRule({
    required this.id,
    required this.communityId,
    required this.title,
    required this.description,
    required this.order,
    required this.createdAt,
  });

  factory CommunityRule.fromJson(Map<String, dynamic> json) {
    return CommunityRule(
      id: json['id'] ?? '',
      communityId: json['community_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'community_id': communityId,
      'title': title,
      'description': description,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
