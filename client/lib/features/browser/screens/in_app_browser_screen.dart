import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:instagram_client/core/theme/app_theme.dart';
import '../models/browser_session.dart';
import '../providers/browser_provider.dart';
import '../widgets/browser_toolbar.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_progress_bar.dart';
import '../widgets/browser_find_bar.dart';
import '../widgets/browser_ad_banner.dart';
import '../widgets/browser_more_menu.dart';
import '../widgets/browser_history_sheet.dart';

class InAppBrowserScreen extends StatefulWidget {
  final BrowserSession session;

  const InAppBrowserScreen({
    super.key,
    required this.session,
  });

  @override
  State<InAppBrowserScreen> createState() =>
      _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen>
    with TickerProviderStateMixin {
  late AnimationController _toolbarCtrl;
  late Animation<Offset> _toolbarSlide;
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;

  final _urlBarCtrl = TextEditingController();
  final _urlBarFocus = FocusNode();
  bool _isUrlBarFocused = false;

  late BrowserProvider _browserProvider;

  @override
  void initState() {
    super.initState();

    _browserProvider = BrowserProvider();

    // Toolbar hide/show animation
    _toolbarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _toolbarSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _toolbarCtrl,
      curve: Curves.easeInOut,
    ));

    // Entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _entryCtrl.forward();

    _urlBarCtrl.text = widget.session.url;
    _urlBarFocus.addListener(_onUrlFocusChange);
  }

  void _onUrlFocusChange() {
    setState(() => _isUrlBarFocused = _urlBarFocus.hasFocus);
    if (_urlBarFocus.hasFocus) {
      _urlBarCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _urlBarCtrl.text.length,
      );
    }
  }

  @override
  void dispose() {
    _toolbarCtrl.dispose();
    _entryCtrl.dispose();
    _urlBarCtrl.dispose();
    _urlBarFocus.dispose();
    _browserProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _browserProvider,
      child: Consumer<BrowserProvider>(
        builder: (ctx, provider, _) {
          return FadeTransition(
            opacity: _entryFade,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Scaffold(
                backgroundColor: isDark
                  ? Colors.black
                  : Colors.white,
                body: Column(
                  children: [
                    // ── Top bar ──
                    _buildTopBar(isDark, provider),

                    // ── Progress bar ──
                    BrowserProgressBar(
                      progress: provider.loadingProgress,
                      isLoading: provider.isLoading,
                    ),

                    // ── Find in page bar ──
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: provider.showFindBar
                        ? BrowserFindBar(
                            onChanged: (val) => provider.findText(val),
                            onNext: provider.findNext,
                            onPrevious: provider.findPrevious,
                            onClose: provider.toggleFindBar,
                            matches: provider.findMatches,
                            currentMatch: provider.currentMatch,
                            isDark: isDark,
                          )
                        : const SizedBox.shrink(),
                    ),

                    // ── Ad banner (if ad) ──
                    if (widget.session.isAd)
                      BrowserAdBanner(session: widget.session),

                    // ── WebView ──
                    Expanded(
                      child: _buildWebView(isDark, provider),
                    ),

                    // ── Bottom toolbar ──
                    AnimatedBuilder(
                      animation: _toolbarSlide,
                      builder: (_, child) => SlideTransition(
                        position: _toolbarSlide,
                        child: child,
                      ),
                      child: BrowserToolbar(
                        provider: provider,
                        isDark: isDark,
                        onClose: () => Navigator.pop(context),
                        onShare: _share,
                        onMore: () => _showMoreMenu(context, provider),
                        onOpenExternal: _openExternal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(bool isDark, BrowserProvider provider) {
    return Container(
      height: 56,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top > 0 ? 8 : 0,
        left: 8,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
              ? const Color(0xFF38383A)
              : const Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Drag handle (only in bottom sheet mode)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Done',
                style: TextStyle(
                  color: AppColors.iosBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          // ── Address bar ──
          Expanded(
            child: BrowserAddressBar(
              controller: _urlBarCtrl,
              focusNode: _urlBarFocus,
              isFocused: _isUrlBarFocused,
              isSecure: provider.isSecure,
              displayUrl: provider.displayUrl,
              currentTitle: provider.currentTitle,
              isDark: isDark,
              onSubmit: (url) {
                _urlBarFocus.unfocus();
                provider.loadUrl(url);
              },
              onClear: () => _urlBarCtrl.clear(),
            ),
          ),

          // Reload / Stop
          GestureDetector(
            onTap: provider.isLoading
              ? provider.stopLoading
              : provider.reload,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  provider.isLoading
                    ? CupertinoIcons.xmark
                    : CupertinoIcons.arrow_clockwise,
                  key: ValueKey(provider.isLoading),
                  size: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView(bool isDark, BrowserProvider provider) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.session.url),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        useOnDownloadStart: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        isFraudulentWebsiteWarningEnabled: true,
        preferredContentMode: provider.isDesktopMode
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
        transparentBackground: false,
        disableContextMenu: false,
        supportZoom: true,
        builtInZoomControls: false,
        displayZoomControls: false,
        allowsBackForwardNavigationGestures: true,
        userAgent: provider.isDesktopMode
          ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) '
            'Version/17.4.1 Mobile/15E148 Safari/604.1',
      ),

      onWebViewCreated: (ctrl) {
        provider.setController(ctrl);
      },

      onLoadStart: (ctrl, url) {
        if (url == null) return;
        final urlStr = url.toString();
        provider.updateUrl(urlStr);
        _urlBarCtrl.text = urlStr;
        provider.updateProgress(0.05);
      },

      onLoadStop: (ctrl, url) async {
        if (url == null) return;
        final urlStr = url.toString();
        provider.updateUrl(urlStr);
        provider.updateProgress(1.0);

        final title = await ctrl.getTitle() ?? '';
        provider.updateTitle(title);
        provider.addToHistory(urlStr, title, null);

        final canBack = await ctrl.canGoBack();
        final canForward = await ctrl.canGoForward();
        provider.updateNavigation(
          canBack: canBack,
          canForward: canForward,
        );

        // Update URL bar when not focused
        if (!_urlBarFocus.hasFocus) {
          _urlBarCtrl.text = urlStr;
        }
      },

      onProgressChanged: (ctrl, progress) {
        provider.updateProgress(progress / 100);
      },

      onTitleChanged: (ctrl, title) {
        if (title != null) provider.updateTitle(title);
      },

      onScrollChanged: (ctrl, x, y) {
        provider.onScrollChanged(y.toDouble());

        // Update toolbar animation
        if (!provider.showToolbar) {
          _toolbarCtrl.forward();
        } else {
          _toolbarCtrl.reverse();
        }
      },

      onUpdateVisitedHistory: (ctrl, url, isReload) async {
        final canBack = await ctrl.canGoBack();
        final canForward = await ctrl.canGoForward();
        provider.updateNavigation(
          canBack: canBack,
          canForward: canForward,
        );
      },

      shouldOverrideUrlLoading: (ctrl, navigationAction) async {
        final url = navigationAction.request.url.toString();

        // Handle special schemes
        if (url.startsWith('tel:') ||
            url.startsWith('mailto:') ||
            url.startsWith('sms:')) {
          await launchUrl(Uri.parse(url));
          return NavigationActionPolicy.CANCEL;
        }

        // Allow normal navigation
        return NavigationActionPolicy.ALLOW;
      },

      onDownloadStartRequest: (ctrl, req) {
        _handleDownload(req.url.toString(), req.suggestedFilename ?? 'file');
      },

      onFindResultReceived: (ctrl, active, found, isDone) {
        provider.updateFindResult(active, found);
      },

      onReceivedError: (ctrl, req, err) {
        // Show error page if main frame
        if (req.isForMainFrame == true) {
          _showErrorPage(err.description);
        }
      },

      onReceivedHttpError: (ctrl, req, res) {
        if (req.isForMainFrame == true && res.statusCode == 404) {
          _showErrorPage('Page not found (404)');
        }
      },

      onConsoleMessage: (ctrl, msg) {
        // Debug only
        if (kDebugMode) debugPrint('Console: ${msg.message}');
      },
    );
  }

  void _share() {
    Share.share(
      _browserProvider.currentUrl,
      subject: _browserProvider.currentTitle,
    );
  }

  void _openExternal() async {
    final url = Uri.parse(_browserProvider.currentUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _handleDownload(String url, String filename) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Download'),
        content: Text('Download "$filename"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              // Trigger download
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showErrorPage(String error) {
    debugPrint('Browser error: $error');
  }

  void _showMoreMenu(BuildContext context, BrowserProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BrowserMoreMenu(
        provider: provider,
        isDark: isDark,
        onFindInPage: () {
          Navigator.pop(context);
          provider.toggleFindBar();
        },
        onDesktopMode: () {
          Navigator.pop(context);
          provider.toggleDesktopMode();
        },
        onReaderMode: () {
          Navigator.pop(context);
          provider.toggleReaderMode();
        },
        onCopyLink: () {
          Navigator.pop(context);
          Clipboard.setData(
            ClipboardData(text: provider.currentUrl),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied')),
          );
        },
        onOpenExternal: () {
          Navigator.pop(context);
          _openExternal();
        },
        onHistory: () {
          Navigator.pop(context);
          _showHistory(context, provider);
        },
      ),
    );
  }

  void _showHistory(BuildContext context, BrowserProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BrowserHistorySheet(
        history: provider.history,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onTap: (item) {
          Navigator.pop(context);
          provider.loadUrl(item.url);
        },
      ),
    );
  }
}
