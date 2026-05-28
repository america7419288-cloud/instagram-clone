import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/browser_session.dart';

class BrowserProvider extends ChangeNotifier {
  // ── State ──
  String _currentUrl = '';
  String _currentTitle = '';
  String? _favicon;
  double _loadingProgress = 0;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDesktopMode = false;
  bool _isReaderMode = false;
  bool _showFindBar = false;
  String _searchText = '';
  int _findMatches = 0;
  int _currentMatch = 0;
  bool _isSecure = false;
  String _displayUrl = '';
  List<BrowserHistoryItem> _history = [];
  bool _showToolbar = true;
  double _lastScrollY = 0;

  // ── Getters ──
  String get currentUrl => _currentUrl;
  String get currentTitle => _currentTitle;
  String? get favicon => _favicon;
  double get loadingProgress => _loadingProgress;
  bool get isLoading => _isLoading;
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;
  bool get isDesktopMode => _isDesktopMode;
  bool get isReaderMode => _isReaderMode;
  bool get showFindBar => _showFindBar;
  String get searchText => _searchText;
  int get findMatches => _findMatches;
  int get currentMatch => _currentMatch;
  bool get isSecure => _isSecure;
  String get displayUrl => _displayUrl;
  List<BrowserHistoryItem> get history => _history;
  bool get showToolbar => _showToolbar;

  InAppWebViewController? _webController;

  void setController(InAppWebViewController ctrl) {
    _webController = ctrl;
  }

  void updateUrl(String url) {
    _currentUrl = url;
    _isSecure = url.startsWith('https://');
    _displayUrl = _formatDisplayUrl(url);
    notifyListeners();
  }

  void updateTitle(String title) {
    _currentTitle = title;
    notifyListeners();
  }

  void updateFavicon(String? favicon) {
    _favicon = favicon;
    notifyListeners();
  }

  void updateProgress(double progress) {
    _loadingProgress = progress;
    _isLoading = progress < 1.0;
    notifyListeners();
  }

  void updateNavigation({bool? canBack, bool? canForward}) {
    if (canBack != null) _canGoBack = canBack;
    if (canForward != null) _canGoForward = canForward;
    notifyListeners();
  }

  void onScrollChanged(double y) {
    final delta = y - _lastScrollY;
    if (delta > 10 && _showToolbar) {
      _showToolbar = false;
      notifyListeners();
    } else if (delta < -10 && !_showToolbar) {
      _showToolbar = true;
      notifyListeners();
    }
    _lastScrollY = y;
  }

  void forceShowToolbar() {
    _showToolbar = true;
    notifyListeners();
  }

  void addToHistory(String url, String title, String? favicon) {
    _history.insert(
      0,
      BrowserHistoryItem(
        url: url,
        title: title,
        favicon: favicon,
        visitedAt: DateTime.now(),
      ),
    );
    if (_history.length > 100) _history = _history.take(100).toList();
  }

  void toggleDesktopMode() {
    _isDesktopMode = !_isDesktopMode;
    notifyListeners();
    _webController?.reload();
  }

  void toggleReaderMode() {
    _isReaderMode = !_isReaderMode;
    notifyListeners();
  }

  void toggleFindBar() {
    _showFindBar = !_showFindBar;
    if (!_showFindBar) {
      _webController?.clearMatches();
      _searchText = '';
      _findMatches = 0;
    }
    notifyListeners();
  }

  Future<void> findText(String text) async {
    _searchText = text;
    if (text.isEmpty) {
      _findMatches = 0;
      _webController?.clearMatches();
    } else {
      await _webController?.findAllAsync(find: text);
    }
    notifyListeners();
  }

  void updateFindResult(int activeMatch, int numberOfMatches) {
    _currentMatch = activeMatch + 1;
    _findMatches = numberOfMatches;
    notifyListeners();
  }

  Future<void> findNext() async {
    await _webController?.findNext(forward: true);
  }

  Future<void> findPrevious() async {
    await _webController?.findNext(forward: false);
  }

  // ── WebView Actions ──
  Future<void> goBack() async => _webController?.goBack();
  Future<void> goForward() async => _webController?.goForward();
  Future<void> reload() async => _webController?.reload();
  Future<void> stopLoading() async => _webController?.stopLoading();

  Future<void> loadUrl(String url) async {
    final normalized = url.startsWith('http')
      ? url : 'https://$url';
    await _webController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(normalized)),
    );
  }

  Future<void> scrollToTop() async {
    await _webController?.scrollTo(x: 0, y: 0, animated: true);
    forceShowToolbar();
  }

  String _formatDisplayUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host;
    } catch (_) {
      return url;
    }
  }

  @override
  void dispose() {
    _webController = null;
    super.dispose();
  }
}
