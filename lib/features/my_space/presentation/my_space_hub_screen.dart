import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/cloudflare_service.dart';
import 'providers/my_space_provider.dart';

// ── Tool entry model (used by search delegate and grid) ──────────────────────

class _ToolEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final String? badge;
  final VoidCallback Function(BuildContext) onTapBuilder;

  const _ToolEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    this.badge,
    required this.onTapBuilder,
  });
}

// ── Tools search delegate ─────────────────────────────────────────────────────

class _ToolsSearchDelegate extends SearchDelegate<void> {
  final List<_ToolEntry> tools;
  _ToolsSearchDelegate({required this.tools});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final results = q.isEmpty
        ? tools
        : tools
            .where((t) =>
                t.label.toLowerCase().contains(q) ||
                t.subtitle.toLowerCase().contains(q))
            .toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No tools found for "$query"',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final tool = results[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.borderOf(context)),
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tool.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: Colors.white, size: 22),
              ),
              title: Text(
                tool.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Inter',
                ),
              ),
              subtitle: Text(
                tool.subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
              onTap: () {
                close(context, null);
                tool.onTapBuilder(context)();
              },
            ),
          );
        },
      ),
    );
  }
}

/// The "My Space" hub — account, stats, tools grid, quick links, and Settings entry.
class MySpaceHubScreen extends ConsumerWidget {
  const MySpaceHubScreen({super.key});

  // ── MP3 Converter instruction sheet ──────────────────────────────────────
  static void _showMp3InstructionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.audiotrack_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MP3 Converter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      'Extract audio from any video',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'How to extract audio:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            ..._mp3Steps.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            const Text(
              'Tip: Open any video in the player, tap ⋮ → Extract Audio (MP3)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontFamily: 'Inter',
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _mp3Steps = [
    'Open any video file in the OTYA Player video player.',
    'Tap the ⋮ (more options) button in the top-right corner.',
    'Select "Extract Audio" from the menu.',
    'The audio is saved as an M4A file in your Downloads folder.',
  ];

  // ── Storage Cleaner sheet ─────────────────────────────────────────────────
  static void _showStorageCleanerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _StorageCleanerSheet(),
    );
  }

  // ── 9-tool entries ────────────────────────────────────────────────────────
  List<_ToolEntry> _buildToolEntries(BuildContext context, WidgetRef ref) => [
        _ToolEntry(
          icon: Icons.folder_open_rounded,
          label: 'Media Manage',
          subtitle: 'Browse & organise',
          gradient: const [Color(0xFFFB923C), Color(0xFFEA580C)],
          badge: null,
          onTapBuilder: (ctx) => () => ctx.push('/tools/folders'),
        ),
        _ToolEntry(
          icon: Icons.audiotrack_rounded,
          label: 'MP3 Converter',
          subtitle: 'Extract audio',
          gradient: const [Color(0xFF34D399), Color(0xFF059669)],
          badge: null,
          onTapBuilder: (ctx) => () => _showMp3InstructionSheet(ctx),
        ),
        _ToolEntry(
          icon: Icons.lock_rounded,
          label: 'Vault',
          subtitle: 'Private storage',
          gradient: const [Color(0xFF8C52FF), Color(0xFF6B3FD4)],
          badge: null,
          onTapBuilder: (ctx) => () => ctx.push('/vault'),
        ),
        _ToolEntry(
          icon: Icons.wifi_tethering_rounded,
          label: 'Share & Transfer',
          subtitle: 'AirDrop & web stream',
          gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          badge: null,
          onTapBuilder: (ctx) => () => ctx.push('/airdrop'),
        ),
        _ToolEntry(
          icon: Icons.palette_rounded,
          label: 'Theme',
          subtitle: 'Appearance',
          gradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
          badge: null,
          onTapBuilder: (ctx) => () => ctx.push('/theme'),
        ),
        _ToolEntry(
          icon: Icons.history_rounded,
          label: 'History',
          subtitle: 'Recently played',
          gradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
          badge: null,
          onTapBuilder: (ctx) => () => ctx.push('/history'),
        ),
        _ToolEntry(
          icon: Icons.cleaning_services_rounded,
          label: 'Cleaner',
          subtitle: 'Free up space',
          gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
          badge: null,
          onTapBuilder: (ctx) => () => _showStorageCleanerSheet(ctx),
        ),
        _ToolEntry(
          icon: Icons.bar_chart_rounded,
          label: 'Stats',
          subtitle: 'Your activity',
          gradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
          badge: 'NEW',
          onTapBuilder: (ctx) => () => ctx.push('/stats'),
        ),
        _ToolEntry(
          icon: Icons.graphic_eq_rounded,
          label: 'Equalizer',
          subtitle: 'Audio tuner',
          gradient: const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
          badge: null,
          onTapBuilder: (ctx) => () => ctx.push('/player/equalizer'),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogle    = ref.watch(isSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final photoUrl    = ref.watch(photoUrlProvider);

    final tools = _buildToolEntries(context, ref);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentViolet],
                            ).createShader(b),
                            child: const Text(
                              'My Space',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Inter',
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isGoogle
                                ? 'Welcome back, ${displayName?.split(' ').first ?? 'there'}'
                                : 'Your account & settings',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search icon for tools
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        showSearch(
                          context: context,
                          delegate: _ToolsSearchDelegate(tools: tools),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Avatar
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentViolet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _InitialsAvatar(name: displayName),
                                )
                              : _InitialsAvatar(name: displayName),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Account Card ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isGoogle
                    ? _SignedInCard(
                        displayName: displayName,
                        photoUrl: photoUrl,
                        onSignOut: () => _confirmSignOut(context, ref),
                        onBackup: () => _runBackup(context, ref),
                      ).animate().fadeIn(duration: 300.ms)
                    : _SignInCard(
                        onTap: () => _signIn(context, ref),
                      ).animate().fadeIn(duration: 300.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Tools Grid (3×3) ─────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                delegate: SliverChildListDelegate(
                  tools
                      .map((t) => _BadgeOverlay(
                            badge: t.badge,
                            child: _ToolMiniCard(
                              icon: t.icon,
                              label: t.label,
                              subtitle: t.subtitle,
                              gradient: t.gradient,
                              onTap: t.onTapBuilder(context),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Quick Links (consolidated card) ──────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Column(
                  children: [
                    _QuickLink(
                      icon: Icons.person_rounded,
                      label: 'Account & Profile',
                      subtitle: 'Sign in, backup, about & updates',
                      color: AppColors.accent,
                      onTap: () => context.push('/profile'),
                    ),
                    Divider(height: 1, color: AppColors.borderOf(context)),
                    _QuickLink(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      subtitle: 'Playback, storage, display & more',
                      color: AppColors.accentGreen,
                      onTap: () => context.push('/settings'),
                    ),
                    Divider(height: 1, color: AppColors.borderOf(context)),
                    _QuickLink(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Feedback',
                      subtitle: 'Report issues or send feedback',
                      color: AppColors.accentViolet,
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set Display Name', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(authNotifierProvider.notifier).signIn(userId: const Uuid().v4(), displayName: name.trim());
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter')),
        content: const Text(
          'Your playlists and history stay on this device.',
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
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _runBackup(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authNotifierProvider).userId ?? '';
    if (userId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in first to back up your data.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Backing up to cloud…'),
      duration: Duration(seconds: 30),
      backgroundColor: AppColors.surface,
    ));
    final ok = await CloudflareService.instance.backupAll(userId);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '✅ Backup complete' : '❌ Backup failed'),
      backgroundColor: ok ? AppColors.surface : AppColors.error,
    ));
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  final String? name;
  const _InitialsAvatar({this.name});

  @override
  Widget build(BuildContext context) {
    final initials = () {
      if (name == null || name!.isEmpty) return '?';
      final parts = name!.trim().split(' ');
      if (parts.length == 1) return parts[0][0].toUpperCase();
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }();
    return Container(
      color: AppColors.accentViolet.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  final String? displayName;
  final String? photoUrl;
  final VoidCallback onSignOut;
  final VoidCallback onBackup;
  const _SignedInCard({
    this.displayName,
    this.photoUrl,
    required this.onSignOut,
    required this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _InitialsAvatar(name: displayName),
                    )
                  : _InitialsAvatar(name: displayName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName ?? 'Google User',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Signed in with Google',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: onBackup,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Backup',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onSignOut,
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SignInCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: const Center(
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.accent,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set your display name',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Personalise your experience',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentViolet],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ── Badge Overlay ─────────────────────────────────────────────────────────────

class _BadgeOverlay extends StatelessWidget {
  final Widget child;
  final String? badge; // e.g. 'NEW', 'HOT', or null
  const _BadgeOverlay({required this.child, this.badge});

  @override
  Widget build(BuildContext context) {
    if (badge == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tool Mini Card ────────────────────────────────────────────────────────────

class _ToolMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ToolMiniCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.28),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8C94A8),
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Storage Cleaner Sheet ─────────────────────────────────────────────────

class _StorageCleanerSheet extends ConsumerStatefulWidget {
  const _StorageCleanerSheet();

  @override
  ConsumerState<_StorageCleanerSheet> createState() =>
      _StorageCleanerSheetState();
}

class _StorageCleanerSheetState extends ConsumerState<_StorageCleanerSheet> {
  bool _clearing = false;
  bool _cleared = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D6A), Color(0xFFCC2244)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cleaning_services_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Storage Cleaner',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    'Free up space used by the app',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _CleanerItem(
            icon: Icons.history_rounded,
            label: 'Seek Position Cache',
            description:
                'Saved playback positions for all tracks. Safe to clear — '
                'the app will start tracks from the beginning next time.',
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
          if (_cleared)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accentGreen.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.accentGreen, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cache cleared successfully!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _clearing
                  ? null
                  : () async {
                      setState(() => _clearing = true);
                      await PlayedDatabase.instance.clearAllSeekPositions();
                      try {
                        final tmpDir = await getTemporaryDirectory();
                        final thumbDir = Directory('${tmpDir.path}/otya_thumbs');
                        if (await thumbDir.exists()) await thumbDir.delete(recursive: true);
                      } catch (_) {}
                      if (mounted) {
                        setState(() {
                          _clearing = false;
                          _cleared = true;
                        });
                      }
                    },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D6A), Color(0xFFCC2244)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _clearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Clear Cache',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CleanerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _CleanerItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
