// lib/features/post/data/models/post_tag_model.dart

class PostTagModel {
  final String  id;
  final String  postId;
  final String  userId;
  final String  username;
  final String? fullName;
  final String? avatar;
  final bool    isVerified;
  final double  xPosition;  // 0.0 → 1.0
  final double  yPosition;  // 0.0 → 1.0
  final int     mediaIndex; // which image in carousel
  final bool    isAccepted;

  const PostTagModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.fullName,
    this.avatar,
    this.isVerified  = false,
    required this.xPosition,
    required this.yPosition,
    this.mediaIndex  = 0,
    this.isAccepted  = false,
  });

  factory PostTagModel.fromJson(Map<String, dynamic> json) {
    return PostTagModel(
      id:         json['id']?.toString() ?? '',
      postId:     json['postId']?.toString() ?? '',
      userId:     json['userId']?.toString() ?? '',
      username:   json['username']?.toString() ?? '',
      fullName:   json['fullName']?.toString(),
      avatar:     json['avatar']?.toString(),
      isVerified: json['isVerified'] == true,
      xPosition:  double.tryParse(json['xPosition']?.toString() ?? '0.5') ?? 0.5,
      yPosition:  double.tryParse(json['yPosition']?.toString() ?? '0.5') ?? 0.5,
      mediaIndex: int.tryParse(json['mediaIndex']?.toString() ?? '0') ?? 0,
      isAccepted: json['isAccepted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'postId':     postId,
    'userId':     userId,
    'xPosition':  xPosition,
    'yPosition':  yPosition,
    'mediaIndex': mediaIndex,
  };
}
