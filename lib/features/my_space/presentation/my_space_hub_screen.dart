import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/feature_discovery_service.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/remote_control_service.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../search/smart_search_sheet.dart';
import 'providers/my_space_provider.dart';

class _MeFeature {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback Function(BuildContext context) action;

  const _MeFeature({
    required this.key,
    required this.icon,
    required this.label,
    required this.action,
  });
}

class MySpaceHubScreen extends ConsumerWidget {
  const MySpaceHubScreen({super.key});

  List<_MeFeature> _features(BuildContext context, WidgetRef ref) {
    final remote = RemoteControlService.instance;
    return [
      _MeFeature(
        key: 'transfer',
        icon: Icons.swap_horiz_rounded,
        label: 'Transfer',
        action: (_) => () async {
          await FeatureDiscoveryService.instance.markOpened('transfer');
          if (context.mounted) context.push('/transfer');
        },
      ),
      _MeFeature(
        key: 'files',
        icon: Icons.folder_open_rounded,
        label: 'Files',
        action: (_) => () => context.push('/tools/folders'),
      ),
      _MeFeature(
        key: 'private',
        icon: Icons.lock_outline_rounded,
        label: 'Private',
        action: (_) => () {
          if (remote.featureEnabled('safe')) context.push('/vault');
        },
      ),
      _MeFeature(
        key: 'converter',
        icon: Icons.transform_rounded,
        label: 'Converter',
        action: (_) => () async {
          await FeatureDiscoveryService.instance.markOpened('converter');
          if (context.mounted) _showConverter(context, ref);
        },
      ),
      _MeFeature(
        key: 'playlists',
        icon: Icons.queue_music_rounded,
        label: 'Playlists',
        action: (_) => () => context.push('/playlists'),
      ),
      _MeFeature(
        key: 'history',
        icon: Icons.history_rounded,
        label: 'History',
        action: (_) => () => context.push('/history'),
      ),
      _MeFeature(
        key: 'tools',
        icon: Icons.tune_rounded,
        label: 'Tools',
        action: (_) => () => _showTools(context, ref),
      ),
      _MeFeature(
        key: 'personalize',
        icon: Icons.auto_awesome_rounded,
        label: 'Personalize',
        action: (_) => () => context.push('/theme'),
      ),
      _MeFeature(
        key: 'storage',
        icon: Icons.storage_rounded,
        label: 'Storage',
        action: (_) => () => context.push('/settings/storage'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final photoUrl = ref.watch(photoUrlProvider);
    final features = _features(context, ref);

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
                      child: Text(
                        'Me',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1,
                          letterSpacing: -1.2,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimaryOf(context),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    _TopButton(
                      icon: Icons.search_rounded,
                      onTap: () => SmartSearchSheet.show(context),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: _Avatar(
                        photoUrl: photoUrl,
                        displayName: displayName,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _FeatureTile(feature: features[index]),
                  childCount: features.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
            const SliverToBoxAdapter(child: _SectionTitle('Settings')),
            SliverToBoxAdapter(
              child: _ListGroup(
                children: [
                  _ListRow(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle:
                        'Playback, video, audio, notifications and permissions',
                    onTap: () => context.push('/settings'),
                    last: true,
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            const SliverToBoxAdapter(child: _SectionTitle('Support')),
            SliverToBoxAdapter(
              child: _ListGroup(
                children: [
                  _ListRow(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Ask OTYA',
                    subtitle: 'Ask questions or get help with OTYA',
                    onTap: () => context.push('/support'),
                  ),
                  _ListRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Help & support',
                    subtitle: 'Guides, feedback and contact',
                    onTap: () => context.push('/about'),
                    last: true,
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            const SliverToBoxAdapter(child: _SectionTitle('About')),
            SliverToBoxAdapter(
              child: _ListGroup(
                children: [
                  _ListRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About OTYA',
                    subtitle: 'What’s new, privacy, terms and version',
                    onTap: () => context.push('/about'),
                    last: true,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 120,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showConverter(BuildContext context, WidgetRef ref) {
    final videos =
        (ref.read(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[])
            .where((item) => item.isVideo)
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        String? busyId;
        String? resultPath;
        double progress = 0;
        return StatefulBuilder(
          builder: (context, setState) => SizedBox(
            height: MediaQuery.of(context).size.height * .78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderOf(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Converter',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Choose a video to extract its audio locally. No upload or account is required.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (busyId != null) ...[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          minHeight: 5,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Extracting audio…',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (resultPath != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF24D789),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Audio saved as ${resultPath!.split('/').last}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.borderOf(context)),
                Expanded(
                  child: videos.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'No videos found. Add or download a video first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final item = videos[index];
                            final active = busyId == item.id;
                            return ListTile(
                              enabled: busyId == null,
                              leading: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.movie_outlined),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.formattedDuration} · ${item.formattedSize}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: active
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.music_note_rounded,
                                      size: 19,
                                    ),
                              onTap: () async {
                                setState(() {
                                  busyId = item.id;
                                  resultPath = null;
                                  progress = .1;
                                });
                                final output =
                                    await FfmpegService.instance.extractAudio(
                                  videoPath: item.filePath,
                                  onProgress: (value) {
                                    if (sheetContext.mounted) {
                                      setState(() => progress = value);
                                    }
                                  },
                                );
                                if (!sheetContext.mounted) return;
                                if (output != null) {
                                  await ref
                                      .read(mediaLibraryProvider.notifier)
                                      .backgroundRefresh();
                                }
                                if (!sheetContext.mounted) return;
                                setState(() {
                                  busyId = null;
                                  resultPath = output;
                                  progress = 0;
                                });
                                if (output == null) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not extract audio from this video.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: Text(
                    'OTYA extracts the existing audio track to M4A when supported. It does not upload your video.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showTools(BuildContext context, WidgetRef ref) {
    _showSheet(
      context,
      title: 'Tools',
      subtitle: 'Utilities that process or improve media.',
      children: [
        _SheetAction(
          icon: Icons.graphic_eq_rounded,
          title: 'Equalizer',
          subtitle: 'Tune sound and use audio presets',
          onTap: () {
            Navigator.pop(context);
            context.push('/player/equalizer');
          },
        ),
        _SheetAction(
          icon: Icons.content_cut_rounded,
          title: 'Trim video',
          subtitle: 'Choose a video and create a local 30-second clip',
          onTap: () {
            Navigator.pop(context);
            _showTrimPicker(context, ref);
          },
        ),
      ],
    );
  }

  static void _showTrimPicker(BuildContext context, WidgetRef ref) {
    final videos =
        (ref.read(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[])
            .where((item) => item.isVideo)
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(sheetContext),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trim video',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Choose a local video to open the trim tool.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderOf(sheetContext)),
            Expanded(
              child: videos.isEmpty
                  ? const Center(
                      child: Text(
                        'No videos found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final item = videos[index];
                        return ListTile(
                          leading: const Icon(Icons.movie_outlined),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${item.formattedDuration} · ${item.formattedSize}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.push('/tools/whatsapp', extra: item);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatefulWidget {
  final _MeFeature feature;
  const _FeatureTile({required this.feature});

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
  bool _showBadge = false;

  @override
  void initState() {
    super.initState();
    FeatureDiscoveryService.instance.shouldShow(widget.feature.key).then((value) {
      if (mounted) setState(() => _showBadge = value);
    });
  }

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.feature.action(context)();
          if (_showBadge) setState(() => _showBadge = false);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Icon(
                      widget.feature.icon,
                      size: 25,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    widget.feature.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            if (_showBadge)
              Positioned(
                top: 1,
                right: 3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    FeatureDiscoveryService.instance
                        .labelFor(widget.feature.key),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
      );
}

class _ListGroup extends StatelessWidget {
  final List<Widget> children;
  const _ListGroup({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: children),
      );
}

class _ListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  const _ListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            leading: Icon(icon, size: 22),
            title: Text(
              title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: onTap,
          ),
          if (!last)
            Divider(
              height: 1,
              indent: 54,
              color: AppColors.borderOf(context),
            ),
        ],
      );
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22),
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardOf(context),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.trim().isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        trailing:
            onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
