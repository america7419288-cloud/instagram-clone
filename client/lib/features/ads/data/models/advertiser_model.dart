class AdvertiserModel {
  final String id;
  final String? userId;
  final String businessName;
  final String businessEmail;
  final String? businessWebsite;
  final String businessCategory;
  final String? logoUrl;
  final bool isVerified;
  final bool isAppOwner;
  final int balance;
  final String currency;
  final int totalSpent;
  final String status;

  AdvertiserModel({
    required this.id,
    this.userId,
    required this.businessName,
    required this.businessEmail,
    this.businessWebsite,
    required this.businessCategory,
    this.logoUrl,
    required this.isVerified,
    required this.isAppOwner,
    required this.balance,
    required this.currency,
    required this.totalSpent,
    required this.status,
  });

  factory AdvertiserModel.fromJson(Map<String, dynamic> json) {
    return AdvertiserModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? json['user_id'],
      businessName: json['businessName'] ?? json['business_name'] ?? '',
      businessEmail: json['businessEmail'] ?? json['business_email'] ?? '',
      businessWebsite: json['businessWebsite'] ?? json['business_website'],
      businessCategory: json['businessCategory'] ?? json['business_category'] ?? 'other',
      logoUrl: json['logoUrl'] ?? json['logo_url'],
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      isAppOwner: json['isAppOwner'] ?? json['is_app_owner'] ?? false,
      balance: json['balance'] ?? 0,
      currency: json['currency'] ?? 'USD',
      totalSpent: json['totalSpent'] ?? json['total_spent'] ?? 0,
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'businessName': businessName,
      'businessEmail': businessEmail,
      'businessWebsite': businessWebsite,
      'businessCategory': businessCategory,
      'logoUrl': logoUrl,
      'isVerified': isVerified,
      'isAppOwner': isAppOwner,
      'balance': balance,
      'currency': currency,
      'totalSpent': totalSpent,
      'status': status,
    };
  }
}
