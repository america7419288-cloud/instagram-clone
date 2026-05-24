class SavedCollectionModel {
  final String id;
  final String userId;
  final String name;
  final String? coverPostId;
  final int postCount;
  final bool isDefault;

  SavedCollectionModel({
    required this.id,
    required this.userId,
    required this.name,
    this.coverPostId,
    required this.postCount,
    required this.isDefault,
  });

  factory SavedCollectionModel.fromJson(Map<String, dynamic> json) {
    return SavedCollectionModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      name: json['name'] ?? '',
      coverPostId: json['coverPostId'] ?? json['cover_post_id'],
      postCount: json['postCount'] ?? json['post_count'] ?? 0,
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'coverPostId': coverPostId,
    'postCount': postCount,
    'isDefault': isDefault,
  };
}
