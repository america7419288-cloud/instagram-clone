// lib/features/auth/data/models/saved_account_model.dart

import 'dart:convert';

class SavedAccountModel {
  final String  userId;
  final String  username;
  final String  email;
  final String? fullName;
  final String? profilePicture;
  final String  accessToken;
  final String  refreshToken;
  final bool    isActive; // currently logged-in account

  const SavedAccountModel({
    required this.userId,
    required this.username,
    required this.email,
    this.fullName,
    this.profilePicture,
    required this.accessToken,
    required this.refreshToken,
    this.isActive = false,
  });

  // ─── Serialization ────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'userId':         userId,
        'username':       username,
        'email':          email,
        'fullName':       fullName,
        'profilePicture': profilePicture,
        'accessToken':    accessToken,
        'refreshToken':   refreshToken,
        'isActive':       isActive,
      };

  factory SavedAccountModel.fromJson(Map<String, dynamic> json) {
    return SavedAccountModel(
      userId:         json['userId']?.toString() ?? '',
      username:       json['username']?.toString() ?? '',
      email:          json['email']?.toString() ?? '',
      fullName:       json['fullName']?.toString(),
      profilePicture: json['profilePicture']?.toString(),
      accessToken:    json['accessToken']?.toString() ?? '',
      refreshToken:   json['refreshToken']?.toString() ?? '',
      isActive:       json['isActive'] == true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory SavedAccountModel.fromJsonString(String jsonStr) {
    return SavedAccountModel.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }

  SavedAccountModel copyWith({
    String?  userId,
    String?  username,
    String?  email,
    String?  fullName,
    String?  profilePicture,
    String?  accessToken,
    String?  refreshToken,
    bool?    isActive,
  }) {
    return SavedAccountModel(
      userId:         userId         ?? this.userId,
      username:       username       ?? this.username,
      email:          email          ?? this.email,
      fullName:       fullName       ?? this.fullName,
      profilePicture: profilePicture ?? this.profilePicture,
      accessToken:    accessToken    ?? this.accessToken,
      refreshToken:   refreshToken   ?? this.refreshToken,
      isActive:       isActive       ?? this.isActive,
    );
  }
}
