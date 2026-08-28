import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/feature_discovery_service.dart';
import '../../../core/services/remote_control_service.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';

class _MeFeature {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback Function(BuildContext context) action;

  const _MeFeature({required this.key, required this.icon, required this.label, required this.action});
}

class MySpaceHubScreen extends ConsumerWidget {
  const MySpaceHubScreen({super.key});

  List<_MeFeature> _features(BuildContext context) {
    final remote = RemoteControlService.instance;
    return [
      _MeFeature(key: 'transfer', icon: Icons.swap_horiz_rounded, label: 'Transfer', action: (_) => () async {
        await FeatureDiscoveryService.instance.markOpened('transfer');
        if (context.mounted) context.push('/airdrop');
      }),
      _MeFeature(key: 'files', icon: Icons.folder_open_rounded, label: 'Files', action: (_) => () => context.push('/tools/folders')),
      _MeFeature(key: 'private', icon: Icons.lock_outline_rounded, label: 'Private', action: (_) => () {
        if (remote.featureEnabled('safe')) context.push('/vault');
      }),
      _MeFeature(key: 'converter', icon: Icons.audio_file_rounded, label: 'Converter', action: (_) => () async {
        await FeatureDiscoveryService.instance.markOpened('converter');
        if (context.mounted) _showConverter(context);
      }),
      _MeFeature(key: 'playlists', icon: Icons.queue_music_rounded, label: 'Playlists', action: (_) => () => context.push('/playlists')),
      _MeFeature(key: 'history', icon: Icons.history_rounded, label: 'History', action: (_) => () => context.push('/history')),
      _MeFeature(key: 'tools', icon: Icons.tune_rounded, label: 'Tools', action: (_) => () => _showTools(context)),
      _MeFeature(key: 'personalize', icon: Icons.auto_awesome_rounded, label: 'Personalize', action: (_) => () => context.push('/theme')),
      _MeFeature(key: 'storage', icon: Icons.storage_rounded, label: 'Storage', action: (_) => () => context.push('/settings/storage')),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final photoUrl = ref.watch(photoUrlProvider);
    final features = _features(context);

    return WallpaperScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(children: [
                  Expanded(child: Text('Me', style: TextStyle(fontSize: 30, height: 1, letterSpacing: -1.2, fontWeight: FontWeight.w900, color: AppColors.textPrimaryOf(context), fontFamily: 'Inter'))),
                  _TopButton(icon: Icons.search_rounded, onTap: () => _showFeatureSearch(context, features)),
                  const SizedBox(width: 10),
                  GestureDetector(onTap: () => context.push('/profile'), child: _Avatar(photoUrl: photoUrl, displayName: displayName)),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 18, childAspectRatio: 1.05),
                delegate: SliverChildBuilderDelegate((context, index) => _FeatureTile(feature: features[index]), childCount: features.length),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryOf(context))))),
            SliverToBoxAdapter(
              child: _ListGroup(children: [
                _ListRow(icon: Icons.settings_rounded, title: 'Settings', subtitle: 'Playback, video, audio, notifications and permissions', onTap: () => context.push('/settings')),
                _ListRow(icon: Icons.help_outline_rounded, title: 'Help & support', subtitle: 'Guides, Ask OTYA, feedback and contact', onTap: () => context.push('/about')),
                _ListRow(icon: Icons.info_outline_rounded, title: 'About OTYA', subtitle: 'What’s new, privacy, terms and version', onTap: () => context.push('/about'), last: true),
              ]),
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 120)),
          ],
        ),
      ),
    );
  }

  static void _showConverter(BuildContext context) {
    _showSheet(context, title: 'Converter', subtitle: 'Useful conversion without adding another main tab.', children: [
      _SheetAction(icon: Icons.music_note_rounded, title: 'Video → audio', subtitle: 'Open a video and choose Extract audio from its menu.', onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open a video, tap ⋮, then choose Extract audio.')));
      }),
      const _SheetAction(icon: Icons.high_quality_rounded, title: 'Quality options', subtitle: 'Conversion stays local to the device.'),
    ]);
  }

  static void _showTools(BuildContext context) {
    _showSheet(context, title: 'Tools', subtitle: 'Utilities that process or improve media.', children: [
      _SheetAction(icon: Icons.graphic_eq_rounded, title: 'Equalizer', subtitle: 'Sound tuning and presets', onTap: () {
        Navigator.pop(context);
        context.push('/player/equalizer');
      }),
      const _SheetAction(icon: Icons.content_cut_rounded, title: 'Trim', subtitle: 'Open a video and use its menu to trim or prepare a clip.'),
      const _SheetAction(icon: Icons.speed_rounded, title: 'Speed & pitch', subtitle: 'Keep playback controls close to the media using them.'),
    ]);
  }

  static void _showFeatureSearch(BuildContext context, List<_MeFeature> features) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) {
        final query = controller.text.trim().toLowerCase();
        final visible = query.isEmpty ? features : features.where((e) => e.label.toLowerCase().contains(query)).toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.borderOf(context), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 18),
            TextField(controller: controller, autofocus: true, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Find a feature', prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Flexible(child: ListView.builder(shrinkWrap: true, itemCount: visible.length, itemBuilder: (context, index) {
              final feature = visible[index];
              return ListTile(leading: Icon(feature.icon), title: Text(feature.label, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {
                Navigator.pop(sheetContext);
                feature.action(context)();
              });
            })),
          ]),
        );
      }),
    ).whenComplete(controller.dispose);
  }

  static void _showSheet(BuildContext context, {required String title, required String subtitle, required List<Widget> children}) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.cardOf(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.borderOf(context), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimaryOf(context))),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ...children,
        ]),
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
    child: Stack(clipBehavior: Clip.none, children: [
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: AppColors.cardOf(context), borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.borderOf(context))), child: Icon(widget.feature.icon, size: 25, color: AppColors.textPrimaryOf(context))),
        const SizedBox(height: 9),
        Text(widget.feature.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
      ])),
      if (_showBadge) Positioned(top: 1, right: 3, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)), child: Text(FeatureDiscoveryService.instance.labelFor(widget.feature.key), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)))),
    ]),
  );
}

class _ListGroup extends StatelessWidget {
  final List<Widget> children;
  const _ListGroup({required this.children});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: AppColors.cardOf(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderOf(context))), child: Column(children: children));
}

class _ListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;
  const _ListRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.last = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3), leading: Icon(icon, size: 22), title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), trailing: const Icon(Icons.chevron_right_rounded, size: 20), onTap: onTap),
    if (!last) Divider(height: 1, indent: 54, color: AppColors.borderOf(context)),
  ]);
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22)));
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  const _Avatar({this.photoUrl, this.displayName});
  @override
  Widget build(BuildContext context) {
    final initial = (displayName?.trim().isNotEmpty ?? false) ? displayName!.trim()[0].toUpperCase() : 'O';
    return Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.cardOf(context), border: Border.all(color: AppColors.borderOf(context))), clipBehavior: Clip.antiAlias, child: photoUrl != null && photoUrl!.trim().isNotEmpty ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)))) : Center(child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800))));
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SheetAction({required this.icon, required this.title, required this.subtitle, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 21)), title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded), onTap: onTap);
}
