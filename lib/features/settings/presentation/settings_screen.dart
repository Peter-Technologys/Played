import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/played_logo.dart';

// ── Playback Settings ─────────────────────────────────────────

class PlaybackSettings {
  final double defaultSpeed;
  final bool crossfadeEnabled;
  final int crossfadeDurationSec;
  final bool gaplessPlayback;
  final bool resumeOnHeadset;
  final bool pauseOnCall;

  const PlaybackSettings({
    this.defaultSpeed = 1.0,
    this.crossfadeEnabled = false,
    this.crossfadeDurationSec = 3,
    this.gaplessPlayback = true,
    this.resumeOnHeadset = true,
    this.pauseOnCall = true,
  });

  PlaybackSettings copyWith({
    double? defaultSpeed,
    bool? crossfadeEnabled,
    int? crossfadeDurationSec,
    bool? gaplessPlayback,
    bool? resumeOnHeadset,
    bool? pauseOnCall,
  }) =>
      PlaybackSettings(
        defaultSpeed: defaultSpeed ?? this.defaultSpeed,
        crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
        crossfadeDurationSec: crossfadeDurationSec ?? this.crossfadeDurationSec,
        gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
        resumeOnHeadset: resumeOnHeadset ?? this.resumeOnHeadset,
        pauseOnCall: pauseOnCall ?? this.pauseOnCall,
      );
}

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  static const _kSpeed        = 'pb_speed';
  static const _kCrossfade    = 'pb_crossfade';
  static const _kCrossfadeSec = 'pb_crossfade_sec';
  static const _kGapless      = 'pb_gapless';
  static const _kResumeHeadset = 'pb_resume_headset';
  static const _kPauseCall    = 'pb_pause_call';

  PlaybackSettingsNotifier() : super(const PlaybackSettings()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = PlaybackSettings(
      defaultSpeed:        p.getDouble(_kSpeed)        ?? 1.0,
      crossfadeEnabled:    p.getBool(_kCrossfade)      ?? false,
      crossfadeDurationSec: p.getInt(_kCrossfadeSec)  ?? 3,
      gaplessPlayback:     p.getBool(_kGapless)        ?? true,
      resumeOnHeadset:     p.getBool(_kResumeHeadset)  ?? true,
      pauseOnCall:         p.getBool(_kPauseCall)       ?? true,
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSpeed,        state.defaultSpeed);
    await p.setBool(_kCrossfade,      state.crossfadeEnabled);
    await p.setInt(_kCrossfadeSec,    state.crossfadeDurationSec);
    await p.setBool(_kGapless,        state.gaplessPlayback);
    await p.setBool(_kResumeHeadset,  state.resumeOnHeadset);
    await p.setBool(_kPauseCall,      state.pauseOnCall);
  }

  void setSpeed(double v)          { state = state.copyWith(defaultSpeed: v);              _save(); }
  void toggleCrossfade()           { state = state.copyWith(crossfadeEnabled: !state.crossfadeEnabled); _save(); }
  void setCrossfadeDuration(int s) { state = state.copyWith(crossfadeDurationSec: s);      _save(); }
  void toggleGapless()             { state = state.copyWith(gaplessPlayback: !state.gaplessPlayback); _save(); }
  void toggleResumeOnHeadset()     { state = state.copyWith(resumeOnHeadset: !state.resumeOnHeadset); _save(); }
  void togglePauseOnCall()         { state = state.copyWith(pauseOnCall: !state.pauseOnCall); _save(); }
}

final playbackSettingsProvider =
    StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>(
  (_) => PlaybackSettingsNotifier(),
);

// ── Settings Screen ───────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogle    = ref.watch(isGoogleSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final photoUrl    = ref.watch(photoUrlProvider);
    final pb          = ref.watch(playbackSettingsProvider);
    final pbN         = ref.read(playbackSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter',
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [

          // ── Account ──────────────────────────────────────
          const _SectionHeader(label: 'Account'),
          const SizedBox(height: 12),
          if (isGoogle) ...[  
            _AccountCard(
              photoUrl: photoUrl,
              displayName: displayName,
              onSignOut: () => _confirmSignOut(context, ref),
            ).animate().fadeIn(duration: 300.ms),
          ] else ...[  
            _GoogleSignInButton(
              onTap: () => _signInWithGoogle(context, ref),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            const Text(
              'Sign in to sync Pro status and playlists across your devices.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          ],

          const SizedBox(height: 32),

          // ── Playback ──────────────────────────────────────
          const _SectionHeader(label: 'Playback'),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.speed_rounded,
            label: 'Default Speed',
            trailing: GestureDetector(
              onTap: () => _showSpeedPicker(context, pb.defaultSpeed, pbN),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text('${pb.defaultSpeed}x',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.accent, fontFamily: 'Inter',
                    )),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.queue_music_rounded,
            label: 'Gapless Playback',
            subtitle: 'No silence between tracks',
            value: pb.gaplessPlayback,
            onChanged: (_) => pbN.toggleGapless(),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.swap_horiz_rounded,
            label: 'Crossfade',
            subtitle: 'Blend tracks together',
            value: pb.crossfadeEnabled,
            onChanged: (_) => pbN.toggleCrossfade(),
          ),
          if (pb.crossfadeEnabled) ...[  
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.timer_outlined,
              label: 'Crossfade Duration',
              trailing: GestureDetector(
                onTap: () => _showCrossfadePicker(context, pb.crossfadeDurationSec, pbN),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('${pb.crossfadeDurationSec}s',
                      style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Inter',
                      )),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.headphones_rounded,
            label: 'Resume on Headset',
            subtitle: 'Auto-play when headphones connect',
            value: pb.resumeOnHeadset,
            onChanged: (_) => pbN.toggleResumeOnHeadset(),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.phone_in_talk_rounded,
            label: 'Pause During Calls',
            subtitle: 'Auto-pause when a call comes in',
            value: pb.pauseOnCall,
            onChanged: (_) => pbN.togglePauseOnCall(),
          ),

          const SizedBox(height: 32),

          // ── About ─────────────────────────────────────────
          const _SectionHeader(label: 'About'),
          const SizedBox(height: 12),

          // App identity card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: const PlayedLogo(
                    fontSize: 28,
                    letterSpacing: 5,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Your media. Your rules.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Inter')),
                const SizedBox(height: 4),
                const Text('Version 1.1.0 (build 2)',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted, fontFamily: 'Inter')),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                const Text(
                  'A high-performance offline media player built for East Africa. '
                  'Play, organise, and share your videos and music — no internet required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary,
                      height: 1.6, fontFamily: 'Inter'),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.business_rounded,
            label: 'Developer',
            trailing: const Text('PeterSmart Technologies',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Inter')),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.email_outlined,
            label: 'Contact Support',
            subtitle: 'dev@petersmartlink.com',
            onTap: () => _launchEmail(context),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.new_releases_outlined,
            label: "What's New",
            subtitle: 'Version 1.1.0 release notes',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WhatsNewScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _launchUrl(context,
                'https://app.petersmartlink.com/played/privacy'),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.star_outline_rounded,
            label: 'Rate PLAYED',
            subtitle: 'Enjoying the app? Leave a review!',
            onTap: () => _launchUrl(context,
                'https://play.google.com/store/apps/details?id=com.petersmart.played'),
          ),

          const SizedBox(height: 40),
          const Center(child: PlayedFooter()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, double current,
      PlaybackSettingsNotifier notifier) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Default Playback Speed',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: speeds.map((s) {
                final active = s == current;
                return GestureDetector(
                  onTap: () { notifier.setSpeed(s); Navigator.pop(context); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('${s}x',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
                          fontFamily: 'Inter',
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showCrossfadePicker(BuildContext context, int current,
      PlaybackSettingsNotifier notifier) {
    const options = [1, 2, 3, 5, 8, 10];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Crossfade Duration',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: options.map((s) {
                final active = s == current;
                return GestureDetector(
                  onTap: () { notifier.setCrossfadeDuration(s); Navigator.pop(context); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('${s}s',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
                          fontFamily: 'Inter',
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in cancelled or failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter')),
        content: const Text(
          'Your Pro status and playlists will no longer sync across devices. Local data is kept.',
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AuthService.instance.signOut();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'dev@petersmartlink.com',
      queryParameters: {'subject': 'PLAYED App Support'},
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email app.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ── What's New Screen ─────────────────────────────────────────

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  static const _sections = [
    _ChangeSection(
      version: '1.1.0',
      date: 'June 2026',
      isLatest: true,
      items: [
        _ChangeItem(Icons.queue_music_rounded, AppColors.accent,
            'Playlists', 'Create, rename, reorder and play playlists.'),
        _ChangeItem(Icons.picture_in_picture_alt_rounded, AppColors.accentViolet,
            'Mini Player Auto-Show',
            'Mini player now appears automatically when any track starts.'),
        _ChangeItem(Icons.folder_special_rounded, AppColors.accent,
            'Full SD Card Access',
            'MANAGE_EXTERNAL_STORAGE support for all folders on Android 11+.'),
        _ChangeItem(Icons.battery_charging_full_rounded, AppColors.accentGreen,
            'Battery Exemption',
            'Prompts Unrestricted battery mode so playback never stops.'),
        _ChangeItem(Icons.share_rounded, AppColors.accent,
            'Open-With Support',
            'PLAYED now appears in the Android share sheet for audio and video files.'),
      ],
    ),
    _ChangeSection(
      version: '1.0.0',
      date: 'January 2024',
      isLatest: false,
      items: [
        _ChangeItem(Icons.home_rounded, AppColors.accent,
            'My Space',
            'Cinema shelf, Street Tapes shelf, Recently Played timeline.'),
        _ChangeItem(Icons.music_note_rounded, AppColors.accentViolet,
            'Audio Player',
            'Shuffle, repeat, speed, EQ, lyrics, queue, sleep timer, favorites.'),
        _ChangeItem(Icons.videocam_rounded, AppColors.accent,
            'Video Player',
            'Hardware-accelerated VLC, subtitles, PiP, gesture controls.'),
        _ChangeItem(Icons.wifi_tethering_rounded, AppColors.accentViolet,
            'Air-Drop',
            'Zero-data file sharing via Wi-Fi Direct + Bluetooth.'),
        _ChangeItem(Icons.mic_rounded, AppColors.accentPink,
            'Studio',
            'Vocal/instrumental stem splitting for karaoke and DJ drops.'),
        _ChangeItem(Icons.lock_rounded, AppColors.accentViolet,
            'Vault',
            'AES-256 encrypted private media vault with biometric unlock.'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("What's New",
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter',
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: _sections
            .asMap()
            .entries
            .map((e) => _SectionWidget(section: e.value)
                .animate()
                .fadeIn(duration: 400.ms,
                    delay: Duration(milliseconds: e.key * 120))
                .slideY(begin: 0.05, end: 0))
            .toList(),
      ),
    );
  }
}

class _ChangeSection {
  final String version;
  final String date;
  final bool isLatest;
  final List<_ChangeItem> items;
  const _ChangeSection({
    required this.version,
    required this.date,
    required this.isLatest,
    required this.items,
  });
}

class _ChangeItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _ChangeItem(this.icon, this.color, this.title, this.description);
}

class _SectionWidget extends StatelessWidget {
  final _ChangeSection section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text('v${section.version}',
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(width: 10),
            if (section.isLatest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Text('LATEST',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.accent, fontFamily: 'Inter',
                      letterSpacing: 0.8,
                    )),
              ),
            const Spacer(),
            Text(section.date,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        ...section.items.map((item) => _ChangeItemWidget(item: item)),
        const SizedBox(height: 8),
        const Divider(color: AppColors.border, height: 1),
      ],
    );
  }
}

class _ChangeItemWidget extends StatelessWidget {
  final _ChangeItem item;
  const _ChangeItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary, fontFamily: 'Inter',
                    )),
                const SizedBox(height: 2),
                Text(item.description,
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary,
                      height: 1.5, fontFamily: 'Inter',
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account Card ──────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final VoidCallback onSignOut;
  const _AccountCard(
      {this.photoUrl, this.displayName, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: ClipOval(
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _InitialsCircle(name: displayName),
                    )
                  : _InitialsCircle(name: displayName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName ?? 'Google User',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, fontFamily: 'Inter',
                    )),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Syncing across devices',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSignOut,
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  final String? name;
  const _InitialsCircle({this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    return Container(
      color: AppColors.accentViolet.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          )),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Google Sign-In Button ─────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                )),
            SizedBox(width: 12),
            Text('Sign in with Google',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
          ],
        ),
      ),
    );
  }
}

// ── Shared tile widgets ───────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 1.2, fontFamily: 'Inter',
        ));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  const _SettingsTile(
      {required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500, fontFamily: 'Inter',
                )),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500, fontFamily: 'Inter',
                    )),
                if (subtitle != null) ...[  
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      )),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}

class _TappableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _TappableTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500, fontFamily: 'Inter',
                      )),
                  if (subtitle != null) ...[  
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        )),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
