import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/database/played_database.dart';

// ── Tools search delegate ─────────────────────────────────────────────────

class _ToolEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback Function(BuildContext) onTapBuilder;

  const _ToolEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTapBuilder,
  });
}

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

// ── ToolsScreen ───────────────────────────────────────────────────────────

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  // ── MP3 Converter instruction sheet ──────────────────────────────────────
  // Explains how to extract audio from a video using the built-in FFmpeg
  // service. Opened from the MP3 Converter tool card.
  static void _showMp3InstructionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
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
  // Shows seek-position cache info and lets the user clear it in one tap.
  static void _showStorageCleaner(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _StorageCleanerSheet(),
    );
  }

  // 9 tools = 3×3 grid. Each tool lives ONLY here.
  // AirDrop + Web Share merged (same screen). Car Mode accessed from player.
  List<_ToolEntry> _buildToolEntries(BuildContext context, WidgetRef ref) => [
        _ToolEntry(
          icon: Icons.folder_open_rounded,
          label: 'Media Manage',
          subtitle: 'Browse & organise',
          gradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
          onTapBuilder: (ctx) => () => ctx.push('/tools/folders'),
        ),
        _ToolEntry(
          icon: Icons.audiotrack_rounded,
          label: 'MP3 Converter',
          subtitle: 'Extract audio',
          gradient: const [Color(0xFF34D399), Color(0xFF059669)],
          onTapBuilder: (ctx) => () => _showMp3InstructionSheet(ctx),
        ),
        _ToolEntry(
          icon: Icons.lock_rounded,
          label: 'Vault',
          subtitle: 'Private storage',
          gradient: const [Color(0xFF8C52FF), Color(0xFF6B3FD4)],
          onTapBuilder: (ctx) => () => ctx.push('/vault'),
        ),
        _ToolEntry(
          icon: Icons.wifi_tethering_rounded,
          label: 'Share & Transfer',
          subtitle: 'AirDrop & web stream',
          gradient: const [Color(0xFF00D2FF), Color(0xFF0099CC)],
          onTapBuilder: (ctx) => () => ctx.push('/airdrop'),
        ),
        _ToolEntry(
          icon: Icons.palette_rounded,
          label: 'Theme',
          subtitle: 'Appearance',
          gradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
          onTapBuilder: (ctx) => () => ctx.push('/theme'),
        ),
        _ToolEntry(
          icon: Icons.history_rounded,
          label: 'History',
          subtitle: 'Recently played',
          gradient: const [Color(0xFF8C52FF), Color(0xFF00D2FF)],
          onTapBuilder: (ctx) => () => ctx.push('/history'),
        ),
        _ToolEntry(
          icon: Icons.cleaning_services_rounded,
          label: 'Cleaner',
          subtitle: 'Free up space',
          gradient: const [Color(0xFFFF4D6A), Color(0xFFCC2244)],
          onTapBuilder: (ctx) => () => _showStorageCleaner(ctx, ref),
        ),
        _ToolEntry(
          icon: Icons.bar_chart_rounded,
          label: 'Stats',
          subtitle: 'Your activity',
          gradient: const [Color(0xFF8C52FF), Color(0xFF6B3FD4)],
          onTapBuilder: (ctx) => () => ctx.push('/stats'),
        ),
        _ToolEntry(
          icon: Icons.graphic_eq_rounded,
          label: 'Equalizer',
          subtitle: 'Audio tuner',
          gradient: const [Color(0xFF00D2FF), Color(0xFF8C52FF)],
          onTapBuilder: (ctx) => () => ctx.push('/player/equalizer'),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                              'Tools',
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
                          const Text(
                            'Quick utilities for your media',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Tools Grid ───────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, MediaQuery.of(context).padding.bottom + 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                delegate: SliverChildListDelegate(
                  tools
                      .map((t) => _ToolCard(
                            icon: t.icon,
                            label: t.label,
                            subtitle: t.subtitle,
                            gradient: t.gradient,
                            onTap: t.onTapBuilder(context),
                          ))
                      .toList(),
                ),
              ),
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

// ── Tool Card ────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ToolCard({
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
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
