import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/pro_service.dart';

/// Wraps any Pro-only feature.
/// - Active Pro (timer not expired) → shows child directly, no ad needed.
/// - No Pro + internet → shows paywall with rewarded ad.
/// - No Pro + offline → shows friendly offline message, no crash.
class ProGate extends StatefulWidget {
  final Widget child;
  final String featureName;
  final String? featureDescription;

  const ProGate({
    super.key,
    required this.child,
    required this.featureName,
    this.featureDescription,
  });

  @override
  State<ProGate> createState() => _ProGateState();
}

class _ProGateState extends State<ProGate> {
  bool _isPro = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkPro();
  }

  Future<void> _checkPro() async {
    final active = await ProService.instance.isProActive();
    if (mounted) setState(() { _isPro = active; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_isPro) return widget.child;
    return _ProPaywall(
      featureName: widget.featureName,
      featureDescription: widget.featureDescription,
      onProGranted: () => setState(() => _isPro = true),
    );
  }
}

// ── Paywall Screen ────────────────────────────────────────────────

class _ProPaywall extends StatefulWidget {
  final String featureName;
  final String? featureDescription;
  final VoidCallback onProGranted;

  const _ProPaywall({
    required this.featureName,
    required this.featureDescription,
    required this.onProGranted,
  });

  @override
  State<_ProPaywall> createState() => _ProPaywallState();
}

class _ProPaywallState extends State<_ProPaywall> {
  static const _adUnitId = 'ca-app-pub-2517163652161686/6818964871';

  RewardedInterstitialAd? _ad;
  bool _loading = false;
  bool _adReady = false;
  // null = no error, 'offline' = no internet, other string = ad error
  String? _errorState;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    setState(() { _loading = true; _errorState = null; });
    RewardedInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          if (mounted) setState(() { _adReady = true; _loading = false; });
        },
        onAdFailedToLoad: (error) {
          debugPrint('[ProGate] Ad failed: $error');
          if (mounted) {
            // Error code 2 = no internet / network error
            final isOffline = error.code == 2;
            setState(() {
              _loading = false;
              _adReady = false;
              _errorState = isOffline ? 'offline' : 'ad_error';
            });
          }
        },
      ),
    );
  }

  void _watchAd() {
    if (_ad == null) return;
    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => ad.dispose(),
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (mounted) setState(() => _errorState = 'ad_error');
      },
    );
    _ad!.show(
      onUserEarnedReward: (_, reward) async {
        await ProService.instance.grantPro(minutes: 30);
        if (mounted) widget.onProGranted();
      },
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = _errorState == 'offline';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Crown / offline icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isOffline
                        ? [AppColors.textSecondary, AppColors.border]
                        : [AppColors.accent, AppColors.accentViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isOffline ? AppColors.border : AppColors.accent)
                          .withValues(alpha: 0.4),
                      blurRadius: 32, spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  isOffline
                      ? Icons.wifi_off_rounded
                      : Icons.workspace_premium_rounded,
                  color: Colors.black, size: 52,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: 32),

              // Title
              Text(
                isOffline ? 'No Internet' : widget.featureName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: 12),

              // Description
              Text(
                isOffline
                    ? 'Connect to the internet to watch a short ad and unlock ${widget.featureName} free for 30 minutes.'
                    : (widget.featureDescription ??
                        'Watch a short ad to unlock this feature free for 30 minutes.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 12),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (isOffline ? AppColors.border : AppColors.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isOffline ? AppColors.border : AppColors.accent)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isOffline
                      ? '\uD83D\uDCF6  Internet required to load ad'
                      : '\u23f0  Unlocks for 30 minutes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOffline ? AppColors.textSecondary : AppColors.accent,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

              const SizedBox(height: 40),

              // Pro features list (only show when not offline)
              if (!isOffline)
                ..._proFeatures.map((f) => _FeatureRow(icon: f.$1, label: f.$2))
                    .toList()
                    .animate(interval: 60.ms)
                    .fadeIn(duration: 300.ms, delay: 300.ms)
                    .slideX(begin: -0.05),

              if (!isOffline) const SizedBox(height: 40),

              // Ad error message (not offline, but ad failed)
              if (_errorState == 'ad_error')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Ad not available right now. Please try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12),
                  ),
                ),

              // Action button
              GestureDetector(
                onTap: isOffline
                    ? _loadAd  // retry when offline (user may have turned on internet)
                    : (_adReady ? _watchAd : (_loading ? null : _loadAd)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: (_adReady && !isOffline)
                        ? const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentViolet])
                        : null,
                    color: (_adReady && !isOffline) ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: (_adReady && !isOffline)
                        ? null
                        : Border.all(color: AppColors.border),
                    boxShadow: (_adReady && !isOffline)
                        ? [BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 16, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: AppColors.accent, strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOffline
                                    ? Icons.refresh_rounded
                                    : (_adReady
                                        ? Icons.play_circle_filled_rounded
                                        : Icons.refresh_rounded),
                                color: (_adReady && !isOffline)
                                    ? Colors.black
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isOffline
                                    ? 'Retry — Check Connection'
                                    : (_adReady
                                        ? 'Watch Ad — Unlock Free for 30 mins'
                                        : 'Retry Loading Ad'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: (_adReady && !isOffline)
                                      ? Colors.black
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 350.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: 16),

              // Back
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Maybe Later',
                    style: TextStyle(color: AppColors.textSecondary)),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pro features list ─────────────────────────────────────────────

// ignore: prefer_const_declarations
final _proFeatures = [
  (Icons.equalizer_rounded,       'Equalizer & Audio Effects'),
  (Icons.graphic_eq_rounded,      'Studio Stem Splitter'),
  (Icons.lock_rounded,            'Private Vault'),
  (Icons.phone_android_rounded,   'WhatsApp Trimmer'),
  (Icons.speed_rounded,           'Playback Speed Control'),
  (Icons.block_rounded,           'Reduced Ads'),
];

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              )),
          const Spacer(),
          const Icon(Icons.check_rounded, color: AppColors.accent, size: 18),
        ],
      ),
    );
  }
}
