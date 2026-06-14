import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../app/theme/app_colors.dart';

/// Bottom banner ad slot.
/// Only loads the ad when the device has an active internet connection.
/// Collapses to zero height when offline or ad not loaded — no empty bar.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  // Use test ID in debug builds, live ID in release builds.
  static String get _adUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'   // AdMob test banner
      : 'ca-app-pub-2517163652161686/9744511115';  // Production banner

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _triedLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIfOnline();
  }

  Future<void> _loadIfOnline() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = !result.contains(ConnectivityResult.none);
    if (!isOnline || !mounted) return;
    _loadAd();
  }

  void _loadAd() {
    if (_triedLoading) return;
    _triedLoading = true;
    final ad = BannerAd(
      adUnitId: AdBannerSlot._adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] Banner failed: $error');
          ad.dispose();
          // Allow retry on next build
          if (mounted) setState(() => _triedLoading = false);
        },
      ),
    );
    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offline or ad not ready — collapse to nothing, no grey placeholder
    if (!_adLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
