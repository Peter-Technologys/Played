import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/cloudflare_service.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';

class _ToolEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback Function(BuildContext) onTapBuilder;

  const _ToolEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTapBuilder,
  });
}

/// OTYA Hub: useful tools without the old rainbow-card clutter.
class MySpaceHubScreen extends ConsumerWidget {
  const MySpaceHubScreen({super.key});

  List<_ToolEntry> _tools(WidgetRef ref) => [
        _ToolEntry(
          icon: Icons.folder_rounded,
          label: 'Files',
          subtitle: 'Browse your media',
          onTapBuilder: (context) => () => context.push('/tools/folders'),
        ),
        _ToolEntry(
          icon: Icons.wifi_tethering_rounded,
          label: 'Beam',
          subtitle: 'Send files nearby',
          onTapBuilder: (context) => () => context.push('/airdrop'),
        ),
        _ToolEntry(
          icon: Icons.lock_rounded,
          label: 'Safe',
          subtitle: 'Private media vault',
          onTapBuilder: (context) => () => context.push('/vault'),
        ),
        _ToolEntry(
          icon: Icons.history_rounded,
          label: 'History',
          subtitle: 'Recently played',
          onTapBuilder: (context) => () => context.push('/history'),
        ),
        _ToolEntry(
          icon: Icons.graphic_eq_rounded,
          label: 'Sound',
          subtitle: 'Equalizer & tuning',
          onTapBuilder: (context) => () => context.push('/player/equalizer'),
        ),
        _ToolEntry(
          icon: Icons.bar_chart_rounded,
          label: 'Insights',
          subtitle: 'Your listening stats',
          onTapBuilder: (context) => () => context.push('/stats'),
        ),
        _ToolEntry(
          icon: Icons.audiotrack_rounded,
          label: 'Ripper',
          subtitle: 'Extract audio from video',
          onTapBuilder: (context) => () => _showRipperHelp(context),
        ),
        _ToolEntry(
          icon: Icons.cleaning_services_rounded,
          label: 'Clean',
          subtitle: 'Clear OTYA cache',
          onTapBuilder: (context) => () => _cleanCache(context),
        ),
        _ToolEntry(
          icon: Icons.palette_rounded,
          label: 'Appearance',
          subtitle: 'Theme and look',
          onTapBuilder: (context) => () => context.push('/theme'),
        ),
        _ToolEntry(
          icon: Icons.content_cut_rounded,
          label: 'Trim',
          subtitle: 'Prepare clips to share',
          onTapBuilder: (context) => () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Open a video, then use ⋮ → Trim for WhatsApp.'),
              ),
            );
          },
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final photoUrl = ref.watch(photoUrlProvider);
    final tools = _tools(ref);
    final featured = tools.take(4).toList();

    return WallpaperScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OTYA Hub',
                            style: TextStyle(
                              fontSize: 29,
                              height: 1,
                              letterSpacing: -1.1,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryOf(context),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            signedIn
                                ? 'Good to see you, ${_firstName(displayName)}.'
                                : 'Tools when you need them. Nothing in the way.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderButton(
                      icon: Icons.search_rounded,
                      onTap: () => _showAllTools(context, tools, searchFirst: true),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: _Avatar(photoUrl: photoUrl, displayName: displayName),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AccountBanner(
                  signedIn: signedIn,
                  displayName: displayName,
                  onPrimary: signedIn
                      ? () => _runBackup(context, ref)
                      : () => _signIn(context, ref),
                  onProfile: () => context.push('/profile'),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quick actions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAllTools(context, tools),
                      icon: const Icon(Icons.grid_view_rounded, size: 17),
                      label: const Text('All tools'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _FeatureToolCard(tool: featured[index]),
                  childCount: featured.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Manage OTYA',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Column(
                  children: [
                    _ManagementRow(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      subtitle: 'Playback, display and app behaviour',
                      onTap: () => context.push('/settings'),
                    ),
                    Divider(height: 1, color: AppColors.borderOf(context)),
                    _ManagementRow(
                      icon: Icons.person_rounded,
                      title: 'Account',
                      subtitle: 'Profile, sync and updates',
                      onTap: () => context.push('/profile'),
                    ),
                    Divider(height: 1, color: AppColors.borderOf(context)),
                    _ManagementRow(
                      icon: Icons.support_agent_rounded,
                      title: 'Help & feedback',
                      subtitle: 'Get support or report a problem',
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.bottom + 130),
            ),
          ],
        ),
      ),
    );
  }

  static String _firstName(String? name) {
    final clean = name?.trim() ?? '';
    if (clean.isEmpty) return 'there';
    return clean.split(RegExp(r'\s+')).first;
  }

  static void _showAllTools(
    BuildContext context,
    List<_ToolEntry> tools, {
    bool searchFirst = false,
  }) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          final query = controller.text.trim().toLowerCase();
          final visible = query.isEmpty
              ? tools
              : tools.where((tool) =>
                    tool.label.toLowerCase().contains(query) ||
                    tool.subtitle.toLowerCase().contains(query)).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18, 10, 18, MediaQuery.of(context).viewInsets.bottom + 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All tools',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: searchFirst,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Find a tool',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.25,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final tool = visible[index];
                      return _CompactToolCard(
                        tool: tool,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          tool.onTapBuilder(context)();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  static void _showRipperHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extract audio', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context))),
            const SizedBox(height: 10),
            const Text(
              'Open a video, tap ⋮, then choose Extract Audio. OTYA saves the audio as an M4A file and adds it back to your media library.',
              style: TextStyle(fontSize: 13, height: 1.5,
                color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _cleanCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Cleaning OTYA cache…')));
    try {
      await OtyaDatabase.instance.clearAllSeekPositions();
      final tmp = await getTemporaryDirectory();
      for (final name in ['otya_thumbs', 'video_thumbs', 'album_art']) {
        final dir = Directory('${tmp.path}/$name');
        if (await dir.exists()) await dir.delete(recursive: true);
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('OTYA cache cleared.')));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Could not clear all cache files.')));
    }
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref.read(authNotifierProvider.notifier).signIn(
      userId: const Uuid().v4(),
      displayName: name.trim(),
    );
  }

  Future<void> _runBackup(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authNotifierProvider).userId ?? '';
    if (userId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Syncing your OTYA data…')));
    final ok = await CloudflareService.instance.backupAll(userId);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Sync complete.' : 'Sync failed. Try again.')),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Icon(icon, size: 21),
          ),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  const _Avatar({this.photoUrl, this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()[0].toUpperCase()
        : 'O';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.accent.withValues(alpha: .35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _Initial(initial: initial),
            )
          : _Initial(initial: initial),
    );
  }
}

class _Initial extends StatelessWidget {
  final String initial;
  const _Initial({required this.initial});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(initial, style: const TextStyle(
          color: AppColors.accent, fontSize: 17,
          fontWeight: FontWeight.w900, fontFamily: 'Inter')),
      );
}

class _AccountBanner extends StatelessWidget {
  final bool signedIn;
  final String? displayName;
  final VoidCallback onPrimary;
  final VoidCallback onProfile;
  const _AccountBanner({
    required this.signedIn,
    this.displayName,
    required this.onPrimary,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accent.withValues(alpha: .22)),
          boxShadow: [BoxShadow(
            color: AppColors.accent.withValues(alpha: .06), blurRadius: 24)],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                signedIn ? Icons.cloud_done_rounded : Icons.person_add_alt_1_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn ? (displayName ?? 'OTYA account') : 'Make OTYA yours',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryOf(context)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    signedIn ? 'Your data is ready to sync.' : 'Set a name and personalise your Hub.',
                    style: const TextStyle(fontSize: 11.5,
                      color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onPrimary,
              child: Text(signedIn ? 'Sync' : 'Start'),
            ),
            IconButton(
              tooltip: 'Profile',
              onPressed: onProfile,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
}

class _FeatureToolCard extends StatelessWidget {
  final _ToolEntry tool;
  const _FeatureToolCard({required this.tool});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            tool.onTapBuilder(context)();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: .18)),
                  ),
                  child: Icon(tool.icon, color: AppColors.accent, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tool.label, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context))),
                      const SizedBox(height: 3),
                      Text(tool.subtitle, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5,
                          color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CompactToolCard extends StatelessWidget {
  final _ToolEntry tool;
  final VoidCallback onTap;
  const _CompactToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tool.icon, color: AppColors.accent, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tool.label, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context))),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ManagementRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ManagementRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 14,
          fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
        subtitle: Text(subtitle, style: const TextStyle(
          fontSize: 11, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      );
}
