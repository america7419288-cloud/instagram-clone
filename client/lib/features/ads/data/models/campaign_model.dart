class CampaignModel {
  final String id;
  final String advertiserId;
  final String name;
  final String objective;
  final String status;
  final String budgetType;
  final int budgetAmount;
  final int budgetSpent;
  final String bidStrategy;
  final int? bidAmount;
  final DateTime startDate;
  final DateTime? endDate;
  final String timezone;
  final List<int> activeDays;
  final int activeHoursStart;
  final int activeHoursEnd;
  final Map<String, dynamic> targeting;
  final bool placementFeed;
  final bool placementReels;
  final bool placementStories;
  final bool placementExplore;

  // Analytics Metrics
  final int impressions;
  final int clicks;
  final int skips;
  final int videoViews;
  final int videoCompletions;
  final int reach;
  final double frequency;
  final int websiteClicks;
  final int appInstalls;
  final int purchases;

  // Review status
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  // Business Name from populating (admin route)
  final String? businessName;

  CampaignModel({
    required this.id,
    required this.advertiserId,
    required this.name,
    required this.objective,
    required this.status,
    required this.budgetType,
    required this.budgetAmount,
    required this.budgetSpent,
    required this.bidStrategy,
    this.bidAmount,
    required this.startDate,
    this.endDate,
    required this.timezone,
    required this.activeDays,
    required this.activeHoursStart,
    required this.activeHoursEnd,
    required this.targeting,
    required this.placementFeed,
    required this.placementReels,
    required this.placementStories,
    required this.placementExplore,
    required this.impressions,
    required this.clicks,
    required this.skips,
    required this.videoViews,
    required this.videoCompletions,
    required this.reach,
    required this.frequency,
    required this.websiteClicks,
    required this.appInstalls,
    required this.purchases,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    this.businessName,
  });

  // Client computed metrics
  double get ctr {
    if (impressions == 0) return 0.0;
    return (clicks / impressions) * 100;
  }

  double get cpm {
    if (impressions == 0) return 0.0;
    return (budgetSpent / impressions) * 1000;
  }

  double get cpc {
    if (clicks == 0) return 0.0;
    return budgetSpent / clicks;
  }

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    // Check populating for businessName
    String? bName;
    if (json['advertiser'] is Map) {
      bName = json['advertiser']['businessName'] ?? json['advertiser']['business_name'];
    }

    return CampaignModel(
      id: json['id'] ?? '',
      advertiserId: json['advertiserId'] ?? json['advertiser_id'] ?? '',
      name: json['name'] ?? '',
      objective: json['objective'] ?? 'awareness',
      status: json['status'] ?? 'draft',
      budgetType: json['budgetType'] ?? json['budget_type'] ?? 'daily',
      budgetAmount: json['budgetAmount'] ?? json['budget_amount'] ?? 0,
      budgetSpent: json['budgetSpent'] ?? json['budget_spent'] ?? 0,
      bidStrategy: json['bidStrategy'] ?? json['bid_strategy'] ?? 'lowest_cost',
      bidAmount: json['bidAmount'] ?? json['bid_amount'],
      startDate: DateTime.parse(json['startDate'] ?? json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: json['endDate'] != null || json['end_date'] != null
          ? DateTime.parse(json['endDate'] ?? json['end_date'])
          : null,
      timezone: json['timezone'] ?? 'UTC',
      activeDays: List<int>.from(json['activeDays'] ?? json['active_days'] ?? [0, 1, 2, 3, 4, 5, 6]),
      activeHoursStart: json['activeHoursStart'] ?? json['active_hours_start'] ?? 0,
      activeHoursEnd: json['activeHoursEnd'] ?? json['active_hours_end'] ?? 23,
      targeting: Map<String, dynamic>.from(json['targeting'] ?? {}),
      placementFeed: json['placementFeed'] ?? json['placement_feed'] ?? true,
      placementReels: json['placementReels'] ?? json['placement_reels'] ?? true,
      placementStories: json['placementStories'] ?? json['placement_stories'] ?? true,
      placementExplore: json['placementExplore'] ?? json['placement_explore'] ?? false,
      impressions: json['impressions'] ?? 0,
      clicks: json['clicks'] ?? 0,
      skips: json['skips'] ?? 0,
      videoViews: json['videoViews'] ?? json['video_views'] ?? 0,
      videoCompletions: json['videoCompletions'] ?? json['video_completions'] ?? 0,
      reach: json['reach'] ?? 0,
      frequency: (json['frequency'] as num?)?.toDouble() ?? 0.0,
      websiteClicks: json['websiteClicks'] ?? json['website_clicks'] ?? 0,
      appInstalls: json['appInstalls'] ?? json['app_installs'] ?? 0,
      purchases: json['purchases'] ?? 0,
      rejectionReason: json['rejectionReason'] ?? json['rejection_reason'],
      reviewedAt: json['reviewedAt'] != null || json['reviewed_at'] != null
          ? DateTime.parse(json['reviewedAt'] ?? json['reviewed_at'])
          : null,
      reviewedBy: json['reviewedBy'] ?? json['reviewed_by'],
      businessName: bName,
    );
  }
}
