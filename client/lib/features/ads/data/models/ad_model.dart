enum AdType {
  image,
  video,
  carousel,
  storyImage,
  storyVideo,
}

enum AdPlacement {
  feed,
  reels,
  stories,
  explore,
}

enum AdCTAType {
  shopNow,
  learnMore,
  signUp,
  download,
  bookNow,
  contactUs,
  watchMore,
  applyNow,
  getOffer,
  installNow,
  orderNow,
  subscribe,
  noButton,
}

class CarouselCard {
  final String imageUrl;
  final String? headline;
  final String? description;
  final String? ctaUrl;

  CarouselCard({
    required this.imageUrl,
    this.headline,
    this.description,
    this.ctaUrl,
  });

  factory CarouselCard.fromJson(Map<String, dynamic> json) {
    return CarouselCard(
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      headline: json['headline'],
      description: json['description'],
      ctaUrl: json['ctaUrl'] ?? json['cta_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'headline': headline,
      'description': description,
      'ctaUrl': ctaUrl,
    };
  }
}

class AdModel {
  final String adId;
  final String campaignId;
  final String advertiserId;
  final AdType type;
  final AdPlacement placement;

  // Advertiser info
  final String advertiserName;
  final String? advertiserAvatarUrl;

  // Content
  final String primaryText;
  final String? headline;
  final String? description;
  final String? imageUrl;
  final String? videoUrl;
  final int? videoDuration;
  final String? videoThumbnailUrl;
  final List<CarouselCard> carouselCards;

  // CTA
  final AdCTAType ctaType;
  final String ctaUrl;
  final String? storySwipeUpText;
  final String? storyOverlayColor;

  final bool isSponsored;

  AdModel({
    required this.adId,
    required this.campaignId,
    required this.advertiserId,
    required this.type,
    required this.placement,
    required this.advertiserName,
    this.advertiserAvatarUrl,
    required this.primaryText,
    this.headline,
    this.description,
    this.imageUrl,
    this.videoUrl,
    this.videoDuration,
    this.videoThumbnailUrl,
    this.carouselCards = const [],
    required this.ctaType,
    required this.ctaUrl,
    this.storySwipeUpText,
    this.storyOverlayColor,
    this.isSponsored = true,
  });

  factory AdModel.fromJson(Map<String, dynamic> json) {
    return AdModel(
      adId: json['adId'] ?? json['id'] ?? '',
      campaignId: json['campaignId'] ?? json['campaign_id'] ?? '',
      advertiserId: json['advertiserId'] ?? json['advertiser_id'] ?? '',
      type: _parseAdType(json['type'] ?? 'image'),
      placement: _parsePlacement(json['placement'] ?? 'feed'),
      advertiserName: json['advertiserName'] ?? json['advertiser_name'] ?? 'Sponsored',
      advertiserAvatarUrl: json['advertiserAvatarUrl'] ?? json['advertiser_avatar_url'],
      primaryText: json['primaryText'] ?? json['primary_text'] ?? '',
      headline: json['headline'],
      description: json['description'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      videoUrl: json['videoUrl'] ?? json['video_url'],
      videoDuration: json['videoDuration'] ?? json['video_duration'],
      videoThumbnailUrl: json['videoThumbnailUrl'] ?? json['video_thumbnail_url'],
      carouselCards: (json['carouselCards'] as List?)?.map((c) => CarouselCard.fromJson(c)).toList() ??
          (json['carousel_cards'] as List?)?.map((c) => CarouselCard.fromJson(c)).toList() ??
          const [],
      ctaType: _parseCtaType(json['ctaType'] ?? json['cta_type'] ?? 'learn_more'),
      ctaUrl: json['ctaUrl'] ?? json['cta_url'] ?? '',
      storySwipeUpText: json['storySwipeUpText'] ?? json['story_swipe_up_text'] ?? 'See more',
      storyOverlayColor: json['storyOverlayColor'] ?? json['story_overlay_color'] ?? '#000000',
      isSponsored: json['isSponsored'] ?? json['is_sponsored'] ?? true,
    );
  }

  static AdType _parseAdType(String val) {
    switch (val) {
      case 'video':
        return AdType.video;
      case 'carousel':
        return AdType.carousel;
      case 'story_image':
        return AdType.storyImage;
      case 'story_video':
        return AdType.storyVideo;
      case 'image':
      default:
        return AdType.image;
    }
  }

  static AdPlacement _parsePlacement(String val) {
    switch (val) {
      case 'reels':
        return AdPlacement.reels;
      case 'stories':
        return AdPlacement.stories;
      case 'explore':
        return AdPlacement.explore;
      case 'feed':
      default:
        return AdPlacement.feed;
    }
  }

  static AdCTAType _parseCtaType(String val) {
    switch (val) {
      case 'shop_now':
        return AdCTAType.shopNow;
      case 'sign_up':
        return AdCTAType.signUp;
      case 'download':
        return AdCTAType.download;
      case 'book_now':
        return AdCTAType.bookNow;
      case 'contact_us':
        return AdCTAType.contactUs;
      case 'watch_more':
        return AdCTAType.watchMore;
      case 'apply_now':
        return AdCTAType.applyNow;
      case 'get_offer':
        return AdCTAType.getOffer;
      case 'install_now':
        return AdCTAType.installNow;
      case 'order_now':
        return AdCTAType.orderNow;
      case 'subscribe':
        return AdCTAType.subscribe;
      case 'no_button':
        return AdCTAType.noButton;
      case 'learn_more':
      default:
        return AdCTAType.learnMore;
    }
  }

  static String ctaLabel(AdCTAType val) {
    switch (val) {
      case AdCTAType.shopNow:
        return 'Shop Now';
      case AdCTAType.signUp:
        return 'Sign Up';
      case AdCTAType.download:
        return 'Download';
      case AdCTAType.bookNow:
        return 'Book Now';
      case AdCTAType.contactUs:
        return 'Contact Us';
      case AdCTAType.watchMore:
        return 'Watch More';
      case AdCTAType.applyNow:
        return 'Apply Now';
      case AdCTAType.getOffer:
        return 'Get Offer';
      case AdCTAType.installNow:
        return 'Install Now';
      case AdCTAType.orderNow:
        return 'Order Now';
      case AdCTAType.subscribe:
        return 'Subscribe';
      case AdCTAType.noButton:
        return '';
      case AdCTAType.learnMore:
      default:
        return 'Learn More';
    }
  }
}
