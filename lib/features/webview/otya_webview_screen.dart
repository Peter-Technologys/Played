// lib/features/webview/otya_webview_screen.dart
//
// Full-screen in-app WebView with:
//   - AppBar: back button, domain title, refresh, Open in Browser
//   - LinearProgressIndicator while loading
//   - Offline banner — shown when device has no connectivity
//   - Error state with retry + Open in Browser
//   - PopScope for predictive-back gesture (Android 14+)
//   - JavaScript enabled (JavaScriptMode.unrestricted)
//   - Download interception — APK/binary links open in browser
//   - Auth token injected for same-origin requests

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../app/theme/app_colors.dart';
import '../../core/config/environment.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/connectivity_service.dart';

class OtyaWebViewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const OtyaWebViewScreen({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<OtyaWebViewScreen> createState() => _OtyaWebViewScreenState();
}

class _OtyaWebViewScreenState extends State<OtyaWebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading  = true;
  bool _hasError   = false;
  bool _isOffline  = false;
  String? _errorDescription;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _isOffline  = ConnectivityService.instance.isOffline;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError  = false;
              _errorDescription = null;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading  = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            // Only surface main-frame errors — sub-resource failures (ads,
            // analytics) are common and should not block the page.
            if (error.isForMainFrame ?? true) {
              setState(() {
                _isLoading        = false;
                _hasError         = true;
                _errorDescription = error.description;
              });
            }
          },
          onNavigationRequest: (request) {
            // Intercept APK / binary downloads and open them in the browser
            // so the system download manager handles them correctly.
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              final path = uri.path.toLowerCase();
              if (path.endsWith('.apk') ||
                  path.endsWith('.zip') ||
                  path.endsWith('.exe') ||
                  path.endsWith('.dmg')) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Inject auth token for same-origin requests so the WebView session
    // is authenticated when the user is logged in.
    _loadWithAuth();
  }

  Future<void> _loadWithAuth() async {
    final token = await AuthService.instance.getValidToken();
    final uri   = Uri.parse(widget.url);
    final workerHost = Uri.tryParse(Environment.workerUrl)?.host ?? '';

    if (token != null && uri.host == workerHost) {
      // Same-origin: inject the Bearer token as a custom header.
      await _controller.loadRequest(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
    } else {
      await _controller.loadRequest(uri);
    }
  }

  /// Extracts the host (domain) from the current URL for the AppBar title.
  String get _displayTitle {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    try {
      final uri = Uri.parse(_currentUrl);
      return uri.host.isNotEmpty ? uri.host : widget.url;
    } catch (_) {
      return widget.url;
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_currentUrl.isNotEmpty ? _currentUrl : widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open browser.',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _retry() async {
    // Re-check connectivity before retrying.
    final online = await ConnectivityService.checkIsOnline();
    if (!mounted) return;
    if (!online) {
      setState(() => _isOffline = true);
      return;
    }
    setState(() {
      _isLoading  = true;
      _hasError   = false;
      _isOffline  = false;
      _errorDescription = null;
    });
    await _controller.reload();
  }

  // ── Back navigation ───────────────────────────────────────────────────────

  /// Returns true if the WebView can go back (so PopScope should prevent pop).
  Future<bool> _onPopInvoked() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return true; // handled — do not pop the route
    }
    return false; // let the route pop normally
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop = false means we always intercept and decide in onPopInvokedWithResult.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final handled = await _onPopInvoked();
        if (!handled && mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () async {
              final handled = await _onPopInvoked();
              if (!handled && mounted) {
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Inter',
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
              tooltip: 'Refresh',
              onPressed: _retry,
            ),
            IconButton(
              icon: const Icon(
                Icons.open_in_browser_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              tooltip: 'Open in Browser',
              onPressed: _openInBrowser,
            ),
          ],
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            // ── Offline banner ────────────────────────────────────────────
            if (_isOffline)
              Material(
                color: AppColors.error.withValues(alpha: 0.12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No internet connection',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _retry,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ── Main content ──────────────────────────────────────────────
            Expanded(
              child: _hasError || _isOffline
                  ? _buildErrorState()
                  : _buildWebView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return WebViewWidget(controller: _controller);
  }

  Widget _buildErrorState() {
    final isOfflineError = _isOffline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOfflineError
                    ? Icons.wifi_off_rounded
                    : Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOfflineError ? 'No internet connection' : 'Page failed to load',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOfflineError
                  ? 'Connect to Wi-Fi or mobile data and try again.'
                  : (_errorDescription ??
                      'Check your internet connection and try again.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(
                  Icons.open_in_browser_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                label: const Text(
                  'Open in Browser',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: AppColors.accent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
