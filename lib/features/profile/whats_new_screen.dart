import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../core/services/update_service.dart';
import '../../shared/widgets/empty_state.dart';

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  String? _text;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    try {
      final info = await UpdateService.instance.checkForUpdate(force: true);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _text = info == null || info.changelog.trim().isEmpty
            ? null
            : info.changelog.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What's new")),
      body: AnimatedSwitcher(
        duration: AppDimensions.motionStandard,
        child: switch ((_loading, _failed, _text)) {
          (true, _, _) => const _LoadingState(key: ValueKey('loading')),
          (false, true, _) => EmptyState(
              key: const ValueKey('error'),
              icon: Icons.cloud_off_rounded,
              title: 'Couldn’t load what’s new',
              subtitle:
                  'Check your connection and try again. Your local Otya library and playback are unaffected.',
              action: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          (false, false, null) => const EmptyState(
              key: ValueKey('up-to-date'),
              icon: Icons.check_circle_outline_rounded,
              title: 'You’re up to date',
              subtitle:
                  'There are no newer release notes to show for this Otya version.',
            ),
          _ => _ReleaseNotes(
              key: const ValueKey('content'),
              text: _text!,
            ),
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Loading what’s new',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: AppDimensions.space16),
                Text(
                  'Checking for updates…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space20,
        AppDimensions.space16,
        AppDimensions.space20,
        AppDimensions.space32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SelectionArea(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
