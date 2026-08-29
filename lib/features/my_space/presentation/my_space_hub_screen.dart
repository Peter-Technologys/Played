import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/remote_control_service.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../search/smart_search_sheet.dart';
import 'providers/my_space_provider.dart';

class MySpaceHubScreen extends ConsumerWidget {
  const MySpaceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final photoUrl = ref.watch(photoUrlProvider);
    final remote = RemoteControlService.instance;
    final features = <_HubItem>[
      _HubItem('transfer', Icons.swap_horiz_rounded, 'Transfer', () => context.push('/transfer'), enabled: remote.featureEnabled('transfer', fallback: true)),
      _HubItem('files', Icons.folder_open_rounded, 'Files', () => context.push('/tools/folders')),
      _HubItem('private', Icons.lock_outline_rounded, 'Private', () => context.push('/vault'), enabled: remote.featureEnabled('private', fallback: true)),
      _HubItem('converter', Icons.transform_rounded, 'Converter', () => _showConverter(context, ref), enabled: remote.featureEnabled('converter', fallback: true)),
      _HubItem('playlists', Icons.queue_music_rounded, 'Playlists', () => context.push('/playlists')),
      _HubItem('history', Icons.history_rounded, 'History', () => context.push('/history')),
      _HubItem('tools', Icons.tune_rounded, 'Tools', () => _showTools(context, ref)),
      _HubItem('personalize', Icons.palette_outlined, 'Personalize', () => context.push('/theme')),
      _HubItem('storage', Icons.storage_rounded, 'Storage', () => context.push('/settings/storage')),
    ];

    return WallpaperScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/icons/play_store_512.png', width: 38, height: 38),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Me', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                          Text(
                            displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'Your OTYA space',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search OTYA',
                      onPressed: () => SmartSearchSheet.show(context),
                      icon: const Icon(Icons.search_rounded),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: _Avatar(photoUrl: photoUrl, name: displayName),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: .98,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _HubTile(item: features[index]),
                  childCount: features.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _SectionLabel('Account & settings')),
            SliverToBoxAdapter(
              child: _RowGroup(children: [
                _ActionRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  subtitle: 'Optional sign-in, verification, Google and backup',
                  onTap: () => context.push('/profile'),
                ),
                _ActionRow(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'Playback, privacy, device permissions and updates',
                  onTap: () => context.push('/settings'),
                ),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            const SliverToBoxAdapter(child: _SectionLabel('Help & product')),
            SliverToBoxAdapter(
              child: _RowGroup(children: [
                _ActionRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Ask OTYA',
                  subtitle: 'Help with OTYA features and troubleshooting',
                  onTap: () => context.push('/support'),
                ),
                _ActionRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About OTYA',
                  subtitle: 'Version, privacy, terms and product information',
                  onTap: () => context.push('/about'),
                ),
              ]),
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }

  static Future<void> _showConverter(BuildContext context, WidgetRef ref) async {
    final videos = (ref.read(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[])
        .where((item) => item.isVideo)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await _showMediaActionSheet(
      context,
      title: 'Converter',
      subtitle: 'Extract a video’s existing audio track locally. No upload or account is required.',
      items: videos,
      actionIcon: Icons.music_note_rounded,
      actionLabel: 'Extract audio',
      run: (item, progress) => FfmpegService.instance.extractAudio(
        videoPath: item.filePath,
        onProgress: progress,
      ),
      onFinished: () => ref.read(mediaLibraryProvider.notifier).backgroundRefresh(),
    );
  }

  static Future<void> _showTools(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('Media processing tools that work locally on this device.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            _ActionRow(
              icon: Icons.graphic_eq_rounded,
              title: 'Equalizer',
              subtitle: 'Tune audio playback',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/player/equalizer');
              },
            ),
            _ActionRow(
              icon: Icons.content_cut_rounded,
              title: 'Trim video',
              subtitle: 'Create a local clip from a selected video',
              onTap: () {
                Navigator.pop(sheetContext);
                _showTrimPicker(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showTrimPicker(BuildContext context, WidgetRef ref) async {
    final videos = (ref.read(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[])
        .where((item) => item.isVideo)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await _showMediaActionSheet(
      context,
      title: 'Trim video',
      subtitle: 'Create a 30-second clip from the beginning of a video. Use the player Trim action for a custom range.',
      items: videos,
      actionIcon: Icons.content_cut_rounded,
      actionLabel: 'Trim 30 seconds',
      run: (item, progress) {
        final duration = item.duration?.inSeconds.toDouble() ?? 30;
        return FfmpegService.instance.trimVideo(
          videoPath: item.filePath,
          startSec: 0,
          endSec: duration.clamp(1, 30),
          onProgress: progress,
        );
      },
      onFinished: () => ref.read(mediaLibraryProvider.notifier).backgroundRefresh(),
    );
  }

  static Future<void> _showMediaActionSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<MediaItem> items,
    required IconData actionIcon,
    required String actionLabel,
    required Future<String?> Function(MediaItem item, void Function(double) progress) run,
    required Future<void> Function() onFinished,
  }) async {
    String? busyId;
    String? result;
    double progress = 0;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          return SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
                      if (busyId != null) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: progress > 0 ? progress : null),
                      ],
                      if (result != null) ...[
                        const SizedBox(height: 10),
                        Text('Saved: ${result!.replaceAll('\\', '/').split('/').last}', style: const TextStyle(fontSize: 12, color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No local videos are available.', textAlign: TextAlign.center)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final active = busyId == item.id;
                            return ListTile(
                              enabled: busyId == null,
                              leading: const Icon(Icons.movie_outlined),
                              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${item.formattedDuration} · ${item.formattedSize}'),
                              trailing: active
                                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Tooltip(message: actionLabel, child: Icon(actionIcon, color: AppColors.accent)),
                              onTap: busyId != null
                                  ? null
                                  : () async {
                                      setState(() { busyId = item.id; result = null; progress = .1; });
                                      final output = await run(item, (value) {
                                        if (sheetContext.mounted) setState(() => progress = value);
                                      });
                                      if (!sheetContext.mounted) return;
                                      if (output != null) await onFinished();
                                      if (!sheetContext.mounted) return;
                                      setState(() { busyId = null; result = output; progress = 0; });
                                      if (output == null) {
                                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('$actionLabel could not be completed for this file.')));
                                      }
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
    );
  }
}

class _HubItem {
  const _HubItem(this.key, this.icon, this.label, this.onTap, {this.enabled = true});
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.item});
  final _HubItem item;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: item.enabled ? 1 : .42,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: item.enabled
              ? () {
                  HapticFeedback.selectionClick();
                  item.onTap();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 27, color: AppColors.accent),
                const SizedBox(height: 8),
                Text(item.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.name});
  final String? photoUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty == true ? name!.trim()[0] : 'O').toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.cardOf(context),
      backgroundImage: photoUrl?.trim().isNotEmpty == true ? CachedNetworkImageProvider(photoUrl!) : null,
      child: photoUrl?.trim().isNotEmpty == true ? null : Text(initial, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 7),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AppColors.textSecondary)),
      );
}

class _RowGroup extends StatelessWidget {
  const _RowGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, indent: 56, color: AppColors.borderOf(context)),
          ],
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      );
}
