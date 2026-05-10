class AppConstants {
  AppConstants._();

  static const String appName = 'Instagram';
  static const String appVersion = '1.0.0';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://instagram-clone-im0x.onrender.com/api/v1',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://instagram-clone-im0x.onrender.com',
  );

  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String logoutEndpoint = '/auth/logout';
  static const String profileEndpoint = '/auth/me';
  static const String usersEndpoint = '/users';
  static const String postsEndpoint = '/posts';
  static const String feedEndpoint = '/posts/feed';
  static const String storiesEndpoint = '/stories';
  static const String notificationsEndpoint = '/notifications';
  static const String conversationsEndpoint = '/conversations';
  static const String searchEndpoint = '/users/search';
  static const String suggestionsEndpoint = '/users/suggestions';
  static const String exploreEndpoint = '/posts/explore';
  static const String postsUrl = '/posts';
  static const String uploadProfilePicEndpoint = '/users/profile-pic';

  static const String reelsUrl      = '/reels';
  static const String reelsFeedUrl  = '/reels/feed';
  static const String reelsExplore  = '/reels/explore';

  static const String storiesUrl    = '/stories';
  static const String storyFeedUrl  = '/stories/feed';
  static const String highlightsUrl = '/highlights';
  static const String usersUrl      = '/users';


  static const String tokenKey = 'auth_token';
  static const String accessTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';
  static const String themeKey = 'app_theme';

  static const int maxPostImages = 10; // Max images per post
  static const int maxBioLength = 150; // Bio character limit
  static const int maxCaptionLength = 2200; // Caption character limit
  static const int maxUsernameLength = 30; // Username character limit
  static const int postPageSize = 12; // Posts per page
  static const int reelsPageSize = 10; // Reels per page
  static const int commentsPageSize = 20; // Comments per page
  static const int storyDuration = 5; // Story display seconds

  static const double profilePicSize = 40.0;
  static const double profilePicSizeLarge = 86.0;
  static const double storyCircleSize = 64.0;
  static const double postImageHeight = 400.0;
}
