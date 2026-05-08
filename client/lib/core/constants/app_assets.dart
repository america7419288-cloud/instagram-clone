class AppAssets {
  static const String _iconsPath = 'assets/icons/';
  static const String _animationsPath = 'assets/animations/';
  static const String _soundsPath = 'assets/sounds/';

  // Icons
  static const String logo = 'assets/images/instagram_logo.svg';
  
  // New Icons helper
  static String getIcon(String name, {bool isDark = false, String? state, String? type}) {
    final String darkPart = isDark ? 'Yes' : 'No';
    
    // The asset pack is extremely inconsistent with "Dark mode" vs "Dark Mode"
    // Tab=Reels, Tab=Profile, Tab=Like, Tab=IGTV use "Dark Mode" (Capital M)
    // ALL Name= (even Name=Like) and other Tab= (like Tab=Grid) use "Dark mode" (Small m)
    
    bool useCapitalM = false;
    if (name.startsWith('Tab=')) {
      if (name.contains('Reels') || name.contains('Profile') || name.contains('Like') || name.contains('IGTV')) {
        useCapitalM = true;
      }
    }
    
    final String modeLabel = useCapitalM ? 'Dark Mode' : 'Dark mode';
    
    String fileName = '$name, ';
    if (state != null) fileName += 'State=$state, ';
    if (type != null) fileName += 'Type=$type, ';
    
    // Remove trailing comma and space if no state/type was added
    if (fileName.endsWith(', ')) {
      fileName = fileName.substring(0, fileName.length - 2);
    }
    
    if (name.startsWith('Tab=') || name.startsWith('Name=')) {
      return 'assets/icons/$fileName, $modeLabel=$darkPart.svg';
    } else {
      // For Icon= prefixed names
      return 'assets/icons/Icon=$name, $modeLabel=$darkPart.svg';
    }
  }

  static const String homeOutline = 'assets/extra_icons/home_outline.svg';
  static const String homeFill = 'assets/extra_icons/home_fill.svg';
  static const String search = 'assets/extra_icons/search.svg';
  static const String reels = 'assets/extra_icons/reel.svg';
  static const String add = 'assets/extra_icons/new_photo_video.svg';
  static const String flip = '${_iconsPath}flip.svg';
  static const String heart = '${_iconsPath}heart.svg';
  static const String heartFilled = '${_iconsPath}heart_filled.svg';
  static const String comment = '${_iconsPath}comment.svg';
  static const String messenger = '${_iconsPath}messenger.svg';
  static const String save = '${_iconsPath}save.svg';
  static const String grid = '${_iconsPath}grid.svg';
  static const String tagged = '${_iconsPath}tagged.svg';
  static const String menu = '${_iconsPath}menu.svg';
  static const String moreVertical = '${_iconsPath}more_vertical.svg';
  static const String options = '${_iconsPath}options.svg';
  static const String settings = '${_iconsPath}settings.svg';
  static const String back = '${_iconsPath}back.svg';
  static const String close = '${_iconsPath}close.svg';
  static const String verified = '${_iconsPath}verified.svg';

  // Animations
  static const String spinner = '${_animationsPath}spinner.json';
  static const String sparkle = '${_animationsPath}sparkle.json';

  // Sounds
  static const String bleep = '${_soundsPath}bleep.m4a';
  static const String harp = '${_soundsPath}harp.m4a';
  static const String shutter = '${_soundsPath}shutter.m4a';
}
