import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ad_model.dart';
import '../../data/models/campaign_model.dart';
import '../../data/models/advertiser_model.dart';
import '../../data/repositories/ad_service.dart';

// ── ADVERTISER STATE NOTIFIER ─────────────────────────
class AdvertiserState {
  final AdvertiserModel? advertiser;
  final bool isLoading;
  final String? error;

  AdvertiserState({this.advertiser, this.isLoading = false, this.error});

  AdvertiserState copyWith({
    AdvertiserModel? advertiser,
    bool? isLoading,
    String? error,
    bool clearAdvertiser = false,
  }) {
    return AdvertiserState(
      advertiser: clearAdvertiser ? null : (advertiser ?? this.advertiser),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AdvertiserNotifier extends Notifier<AdvertiserState> {
  late AdService _adService;

  @override
  AdvertiserState build() {
    _adService = ref.watch(adServiceProvider);
    Future.microtask(() => loadProfile());
    return AdvertiserState();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _adService.getMyAdvertiser();
      state = state.copyWith(advertiser: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register({
    required String businessName,
    required String businessEmail,
    required String businessCategory,
    String? businessWebsite,
    File? logo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _adService.registerAdvertiser(
        businessName: businessName,
        businessEmail: businessEmail,
        businessCategory: businessCategory,
        businessWebsite: businessWebsite,
        logo: logo,
      );
      state = state.copyWith(advertiser: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String businessName,
    required String businessEmail,
    required String businessCategory,
    String? businessWebsite,
    File? logo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _adService.updateAdvertiser(
        businessName: businessName,
        businessEmail: businessEmail,
        businessCategory: businessCategory,
        businessWebsite: businessWebsite,
        logo: logo,
      );
      state = state.copyWith(advertiser: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final advertiserProvider = NotifierProvider<AdvertiserNotifier, AdvertiserState>(() {
  return AdvertiserNotifier();
});


// ── CAMPAIGNS STATE NOTIFIER ──────────────────────────
class CampaignsState {
  final List<CampaignModel> campaigns;
  final bool isLoading;
  final String? error;

  CampaignsState({this.campaigns = const [], this.isLoading = false, this.error});

  CampaignsState copyWith({
    List<CampaignModel>? campaigns,
    bool? isLoading,
    String? error,
  }) {
    return CampaignsState(
      campaigns: campaigns ?? this.campaigns,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class CampaignsNotifier extends Notifier<CampaignsState> {
  late AdService _adService;

  @override
  CampaignsState build() {
    _adService = ref.watch(adServiceProvider);
    Future.microtask(() => loadCampaigns());
    return CampaignsState();
  }

  Future<void> loadCampaigns() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _adService.getMyCampaigns();
      state = state.copyWith(campaigns: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<CampaignModel> create({
    required String name,
    required String objective,
    required String budgetType,
    required int budgetAmount,
    required String bidStrategy,
    int? bidAmount,
    required DateTime startDate,
    DateTime? endDate,
    required List<int> activeDays,
    required int activeHoursStart,
    required int activeHoursEnd,
    required Map<String, dynamic> targeting,
    required Map<String, bool> placements,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final c = await _adService.createCampaign(
        name: name,
        objective: objective,
        budgetType: budgetType,
        budgetAmount: budgetAmount,
        bidStrategy: bidStrategy,
        bidAmount: bidAmount,
        startDate: startDate,
        endDate: endDate,
        activeDays: activeDays,
        activeHoursStart: activeHoursStart,
        activeHoursEnd: activeHoursEnd,
        targeting: targeting,
        placements: placements,
      );
      state = state.copyWith(campaigns: [c, ...state.campaigns], isLoading: false);
      return c;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> pause(String id) async {
    try {
      await _adService.pauseCampaign(id);
      state = state.copyWith(
        campaigns: state.campaigns.map((c) => c.id == id ? _updateStatus(c, 'paused') : c).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> resume(String id) async {
    try {
      await _adService.resumeCampaign(id);
      state = state.copyWith(
        campaigns: state.campaigns.map((c) => c.id == id ? _updateStatus(c, 'active') : c).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String id) async {
    try {
      await _adService.deleteCampaign(id);
      state = state.copyWith(
        campaigns: state.campaigns.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  CampaignModel _updateStatus(CampaignModel c, String status) {
    return CampaignModel(
      id: c.id,
      advertiserId: c.advertiserId,
      name: c.name,
      objective: c.objective,
      status: status,
      budgetType: c.budgetType,
      budgetAmount: c.budgetAmount,
      budgetSpent: c.budgetSpent,
      bidStrategy: c.bidStrategy,
      bidAmount: c.bidAmount,
      startDate: c.startDate,
      endDate: c.endDate,
      timezone: c.timezone,
      activeDays: c.activeDays,
      activeHoursStart: c.activeHoursStart,
      activeHoursEnd: c.activeHoursEnd,
      targeting: c.targeting,
      placementFeed: c.placementFeed,
      placementReels: c.placementReels,
      placementStories: c.placementStories,
      placementExplore: c.placementExplore,
      impressions: c.impressions,
      clicks: c.clicks,
      skips: c.skips,
      videoViews: c.videoViews,
      videoCompletions: c.videoCompletions,
      reach: c.reach,
      frequency: c.frequency,
      websiteClicks: c.websiteClicks,
      appInstalls: c.appInstalls,
      purchases: c.purchases,
      rejectionReason: c.rejectionReason,
      reviewedAt: c.reviewedAt,
      reviewedBy: c.reviewedBy,
    );
  }
}

final campaignsListProvider = NotifierProvider<CampaignsNotifier, CampaignsState>(() {
  return CampaignsNotifier();
});


// ── ANALYTICS OVERVIEW PROVIDER ───────────────────────
final advertiserOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(adServiceProvider).getAnalyticsOverview();
});


// ── FEED ADS PROVIDER ────────────────────────────────
final feedAdsProvider = FutureProvider.family<List<AdModel>, int>((ref, count) async {
  return ref.watch(adServiceProvider).getFeedAds(count: count);
});

final storyAdsProvider = FutureProvider<List<AdModel>>((ref) async {
  return ref.watch(adServiceProvider).getStoryAds();
});

final reelAdsProvider = FutureProvider<List<AdModel>>((ref) async {
  return ref.watch(adServiceProvider).getReelAds();
});
