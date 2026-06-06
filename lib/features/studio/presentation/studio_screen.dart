import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../data/stem_repository.dart';
import '../../../app/theme/app_colors.dart';

// ── Providers ──────────────────────────────────────────────

enum StudioMode { karaoke, djDrop }
enum StemStatus { idle, uploading, processing, ready, error }

final studioModeProvider = StateProvider<StudioMode>((_) => StudioMode.karaoke);
final selectedFileProvider = StateProvider<File?>((_) => null);
final vocalMixProvider    = StateProvider<double>((_) => 1.0);
final stemRepositoryProvider = Provider<StemRepository>((_) => StemRepository());
final stemStateProvider = StateNotifierProvider<StemStateNotifier, StemState>(
  (ref) => StemStateNotifier(ref.read(stemRepositoryProvider)),
);

class StemState {
  final StemStatus status;
  final String? vocalPath;
  final String? instrumentalPath;
  final String? errorMessage;
  final double progress;
  const StemState({
    this.status = StemStatus.idle,
    this.vocalPath,
    this.instrumentalPath,
    this.errorMessage,
    this.progress = 0.0,
  });
  StemState copyWith({
    StemStatus? status, String? vocalPath, String? instrumentalPath,
    String? errorMessage, double? progress,
  }) => StemState(
    status: status ?? this.status,
    vocalPath: vocalPath ?? this.vocalPath,
    instrumentalPath: instrumentalPath ?? this.instrumentalPath,
    errorMessage: errorMessage ?? this.errorMessage,
    progress: progress ?? this.progress,
  );
}

class StemStateNotifier extends StateNotifier<StemState> {
  final StemRepository _repo;
  StemStateNotifier(this._repo) : super(const StemState());

  Future<void> splitTrack(File file) async {
    state = state.copyWith(status: StemStatus.uploading, progress: 0.1);
    try {
      state = state.copyWith(status: StemStatus.processing, progress: 0.45);
      final result = await _repo.splitAudio(file);
      state = state.copyWith(
        status: StemStatus.ready,
        vocalPath: result.vocalPath,
        instrumentalPath: result.instrumentalPath,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
          status: StemStatus.error, errorMessage: e.toString());
    }
  }

  void reset() => state = const StemState();
}

// ── Screen ──────────────────────────────────────────────────

class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode      = ref.watch(studioModeProvider);
    final stemState = ref.watch(stemStateProvider);
    final file      = ref.watch(selectedFileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            // ── Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('The Studio',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                        )),
                    const SizedBox(height: 2),
                    const Text(
                      'Split any track into vocals + instrumental.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // Mode toggle
                    _ModeToggle(currentMode: mode),
                    const SizedBox(height: 20),

                    // File picker
                    _FilePicker(selectedFile: file),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Active panel ───────────────────────────────────
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.04, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: mode == StudioMode.karaoke
                    ? const _KaraokePanel(key: ValueKey('k'))
                    : const _DjDropPanel(key: ValueKey('d')),
              ),
            ),

            // ── Status / result ────────────────────────────────
            SliverToBoxAdapter(
              child: _StemStatusPanel(state: stemState),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Mode Toggle ────────────────────────────────────────────

class _ModeToggle extends ConsumerWidget {
  final StudioMode currentMode;
  const _ModeToggle({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Tab(
            label: '\uD83C\uDFA4  Choir & Karaoke',
            isActive: currentMode == StudioMode.karaoke,
            onTap: () => ref.read(studioModeProvider.notifier).state =
                StudioMode.karaoke,
          ),
          _Tab(
            label: '\uD83C\uDF99  DJ Drop',
            isActive: currentMode == StudioMode.djDrop,
            onTap: () => ref.read(studioModeProvider.notifier).state =
                StudioMode.djDrop,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 10, spreadRadius: 1)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.black : AppColors.textSecondary,
                fontFamily: 'SpaceGrotesk',
              )),
        ),
      ),
    );
  }
}

// ── File Picker ────────────────────────────────────────────

class _FilePicker extends ConsumerWidget {
  final File? selectedFile;
  const _FilePicker({required this.selectedFile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFile = selectedFile != null;
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.audio, allowMultiple: false);
        if (result != null && result.files.single.path != null) {
          ref.read(selectedFileProvider.notifier).state =
              File(result.files.single.path!);
          ref.read(stemStateProvider.notifier).reset();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? AppColors.accent : AppColors.border,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasFile
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.audio_file_rounded,
                  color: hasFile ? AppColors.accent : AppColors.textSecondary,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile
                        ? selectedFile!.path.split('/').last
                        : 'Tap to select an audio track',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasFile
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasFile)
                    const Text('MP3 / WAV / AAC',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: hasFile ? AppColors.accent : AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Karaoke Panel ───────────────────────────────────────────

class _KaraokePanel extends ConsumerWidget {
  const _KaraokePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocalMix  = ref.watch(vocalMixProvider);
    final file      = ref.watch(selectedFileProvider);
    final stemState = ref.watch(stemStateProvider);
    final busy = stemState.status == StemStatus.uploading ||
        stemState.status == StemStatus.processing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: '\uD83C\uDFA4',
            title: 'Choir & Karaoke Mode',
            subtitle:
                'Fade out vocals and sing along to the pure instrumental.',
          ),
          const SizedBox(height: 24),

          // Vocal fade label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VOCAL FADE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                    fontFamily: 'SpaceGrotesk',
                  )),
              Text(
                vocalMix < 0.15
                    ? '\uD83C\uDFB8 Instrumental'
                    : vocalMix > 0.85
                        ? '\uD83C\uDFA4 Full Vocals'
                        : '\uD83C\uDFB5 Blended',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Neon slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.15),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: vocalMix,
              onChanged: (v) =>
                  ref.read(vocalMixProvider.notifier).state = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Instrumental Only',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
                Text('Full Vocals',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 28),
          _ActionButton(
            label: 'Split & Practice',
            icon: Icons.mic_external_on_rounded,
            enabled: file != null && !busy,
            onTap: file != null
                ? () => ref.read(stemStateProvider.notifier).splitTrack(file)
                : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── DJ Drop Panel ───────────────────────────────────────────

class _DjDropPanel extends ConsumerWidget {
  const _DjDropPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file      = ref.watch(selectedFileProvider);
    final stemState = ref.watch(stemStateProvider);
    final busy = stemState.status == StemStatus.uploading ||
        stemState.status == StemStatus.processing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: '\uD83C\uDF99',
            title: 'DJ Drop Mode',
            subtitle:
                'Strip the beat. Isolate a clean vocal stem for your mix.',
          ),
          const SizedBox(height: 24),

          // Visual flow diagram
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StemChip(Icons.record_voice_over_rounded,
                    'Vocals', AppColors.accent, true),
                const Icon(Icons.add, color: AppColors.textSecondary, size: 16),
                _StemChip(Icons.piano_rounded,
                    'Instruments', AppColors.textSecondary, false),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.accent, size: 18),
                _StemChip(Icons.mic_rounded,
                    'Vocal Stem', AppColors.accentViolet, true),
              ],
            ),
          ),

          const SizedBox(height: 28),
          _ActionButton(
            label: 'Extract Vocal Drop',
            icon: Icons.flash_on_rounded,
            enabled: file != null && !busy,
            onTap: file != null
                ? () => ref.read(stemStateProvider.notifier).splitTrack(file)
                : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Stem Status Panel ────────────────────────────────────────

class _StemStatusPanel extends StatelessWidget {
  final StemState state;
  const _StemStatusPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == StemStatus.idle) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: state.status == StemStatus.error
                ? AppColors.error
                : AppColors.accent,
          ),
        ),
        child: _buildBody(),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }

  Widget _buildBody() {
    switch (state.status) {
      case StemStatus.uploading:
      case StemStatus.processing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.status == StemStatus.uploading
                  ? 'Uploading track...'
                  : 'Splitting stems...',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'SpaceGrotesk'),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.progress,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Powered by Spleeter · Cached locally after split',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        );

      case StemStatus.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.accent, size: 20),
                SizedBox(width: 8),
                Text('Stems Ready — Saved Offline',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'SpaceGrotesk',
                    )),
              ],
            ),
            const SizedBox(height: 14),
            _StemRow(label: '\uD83C\uDFA4 Vocals', path: state.vocalPath),
            const SizedBox(height: 8),
            _StemRow(label: '\uD83C\uDFB8 Instrumental',
                path: state.instrumentalPath),
          ],
        );

      case StemStatus.error:
        return Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.errorMessage ?? 'Something went wrong.',
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _StemRow extends StatelessWidget {
  final String label;
  final String? path;
  const _StemRow({required this.label, this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'SpaceGrotesk',
              )),
          const Spacer(),
          if (path != null)
            const Icon(Icons.play_circle_filled_rounded,
                color: AppColors.accent, size: 28)
          else
            const Icon(Icons.hourglass_empty_rounded,
                color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final String icon, title, subtitle;
  const _PanelHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'SpaceGrotesk',
                  )),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StemChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  const _StemChip(this.icon, this.label, this.color, this.active);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: active ? color : AppColors.textSecondary, size: 22),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 9,
              color: active ? color : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontFamily: 'SpaceGrotesk',
            )),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.enabled,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet])
              : null,
          color: enabled ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: enabled ? null : Border.all(color: AppColors.border),
          boxShadow: enabled
              ? [BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: enabled ? Colors.black : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.black : AppColors.textSecondary,
                  fontFamily: 'SpaceGrotesk',
                )),
          ],
        ),
      ),
    );
  }
}
