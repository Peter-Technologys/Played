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

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  List<_ToolEntry> _buildToolEntries(BuildContext context, WidgetRef ref) => [
        _ToolEntry(
          icon: Icons.lock_rounded,
          label: 'Vault',
          subtitle: 'Private storage',
          gradient: const [Color(0xFF8C52FF), Color(0xFF6B3FD4)],
          onTapBuilder: (ctx) => () => ctx.push('/vault'),
        ),
        _ToolEntry(
          icon: Icons.wifi_tethering_rounded,
          label: 'Air-Drop',
          subtitle: 'P2P transfer',
          gradient: const [Color(0xFF00D2FF), Color(0xFF0099CC)],
          onTapBuilder: (ctx) => () => ctx.push('/airdrop'),
        ),
        _ToolEntry(
          icon: Icons.audiotrack_rounded,
          label: 'MP3 Convert',
          subtitle: 'Extract audio',
          gradient: const [Color(0xFF34D399), Color(0xFF059669)],
          onTapBuilder: (ctx) => () => _showMp3InstructionSheet(ctx),
        ),
        _ToolEntry(
          icon: Icons.content_cut_rounded,
          label: 'Trimmer',
          subtitle: 'Clip & compress',
          gradient: const [Color(0xFFF472B6), Color(0xFFDB2777)],
          onTapBuilder: (ctx) => () => _showTrimmerInstructionSheet(ctx),
        ),
        _ToolEntry(
          icon: Icons.palette_rounded,
          label: 'Theme',
          subtitle: 'Appearance',
          gradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
          onTapBuilder: (ctx) => () => ctx.push('/theme'),
        ),
        _ToolEntry(
          icon: Icons.graphic_eq_rounded,
          label: 'Equalizer',
          subtitle: 'Audio tuner',
          gradient: const [Color(0xFF00D2FF), Color(0xFF8C52FF)],
          onTapBuilder: (ctx) => () => ctx.push('/player/equalizer'),
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
          icon: Icons.directions_car_rounded,
          label: 'Car Mode',
          subtitle: 'Distraction-free',
          gradient: const [Color(0xFF1DB954), Color(0xFF0D8A3C)],
          onTapBuilder: (ctx) => () => ctx.push('/player/car-mode'),
        ),
        _ToolEntry(
          icon: Icons.cast_rounded,
          label: 'Web Share',
          subtitle: 'Stream to browser',
          gradient: const [Color(0xFF00D2FF), Color(0xFF0066CC)],
          onTapBuilder: (ctx) => () => ctx.push('/airdrop'),
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
                  tools.map((t) => _ToolCard(
                    icon: t.icon,
                    label: t.label,
                    subtitle: t.subtitle,
                    gradient: t.gradient,
                    onTap: t.onTapBuilder(context),
                  )).toList(),
                ),
              ),
            ),


          ],
        ),
      ),
    );
  }

  void _showMp3InstructionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
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
            const Text(
              'Extract Audio (MP3)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            _InstructionStep(number: '1', text: 'Go to the Video tab'),
            _InstructionStep(number: '2', text: 'Tap any video to open it'),
            _InstructionStep(number: '3', text: 'Tap the ⋮ menu (top-right)'),
            _InstructionStep(number: '4', text: "Tap 'Extract Audio'"),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/');
                    },
                    icon: const Icon(Icons.play_circle_rounded,
                        color: Colors.black, size: 18),
                    label: const Text('Go to Videos',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                  ),
                  child: const Text('Dismiss',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTrimmerInstructionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
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
            const Text(
              'WhatsApp Trimmer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            _InstructionStep(number: '1', text: 'Go to the Video tab'),
            _InstructionStep(number: '2', text: 'Tap any video to open it'),
            _InstructionStep(number: '3', text: 'Tap the ⋮ menu (top-right)'),
            _InstructionStep(number: '4', text: "Tap 'Trim for WhatsApp'"),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/');
                    },
                    icon: const Icon(Icons.play_circle_rounded,
                        color: Colors.black, size: 18),
                    label: const Text('Go to Videos',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                  ),
                  child: const Text('Dismiss',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStorageCleaner(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Cache?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        content: const Text(
          'Removes temporary thumbnails and processing files. Your media and playlists are safe.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await PlayedDatabase.instance.clearAllSeekPositions();
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared ✅'),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

// ── Instruction Step ─────────────────────────────────────────────────

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
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
