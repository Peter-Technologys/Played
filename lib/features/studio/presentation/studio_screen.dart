import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../data/stem_repository.dart';
import '../../../app/theme/app_colors.dart';

// ── Providers ──────────────────────────────────────────────

enum StudioMode { karaoke, djDrop }

final studioModeProvider =
    StateProvider<StudioMode>((_) => StudioMode.karaoke);
final selectedFileProvider = StateProvider<File?>((_) => null);
final vocalMixProvider = StateProvider<double>((_) => 1.0);
final stemRepositoryProvider =
    Provider<StemRepository>((_) => StemRepository());
final stemStateProvider =
    StateNotifierProvider<StemStateNotifier, StemState>(
  (ref) => StemStateNotifier(ref.read(stemRepositoryProvider)),
);

// ── State ──────────────────────────────────────────────────

enum StemStatus { idle, uploading, processing, ready, error }

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
    StemStatus? status,
    String? vocalPath,
    String? instrumentalPath,
    String? errorMessage,
    double? progress,
  }) =>
      StemState(
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
      state = state.copyWith(status: StemStatus.processing, progress: 0.4);
      final result = await _repo.splitAudio(file);
      state = state.copyWith(
        status: StemStatus.ready,
        vocalPath: result.vocalPath,
        instrumentalPath: result.instrumentalPath,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: StemStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const StemState();
}

// ── Main Screen ──────────────────────────────────────────────

class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(studioModeProvider);
    final stemState = ref.watch(stemStateProvider);
    final selectedFile = ref.watch(selectedFileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The Studio',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Split any track. Offline. Instantly.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ModeToggle(currentMode: mode),
                    const SizedBox(height: 28),
                    _FilePicker(selectedFile: selectedFile),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: mode == StudioMode.karaoke
                    ? const _KaraokePanel(key: ValueKey('karaoke'))
                    : const _DjDropPanel(key: ValueKey('djdrop')),
              ),
            ),
            SliverToBoxAdapter(
              child: _StemStatusPanel(state: stemState),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Mode Toggle ─────────────────────────────────────────────

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
          _ToggleOption(
            label: '\uD83C\uDFA4  Choir & Karaoke',
            isActive: currentMode == StudioMode.karaoke,
            onTap: () => ref.read(studioModeProvider.notifier).state =
                StudioMode.karaoke,
          ),
          _ToggleOption(
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

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.black : AppColors.textSecondary,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
        ),
      ),
    );
  }
}

// ── File Picker ─────────────────────────────────────────────

class _FilePicker extends ConsumerWidget {
  final File? selectedFile;
  const _FilePicker({required this.selectedFile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          ref.read(selectedFileProvider.notifier).state =
              File(result.files.single.path!);
          ref.read(stemStateProvider.notifier).reset();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedFile != null
                ? AppColors.accent
                : AppColors.border,
            width: selectedFile != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.audio_file_rounded,
              color: selectedFile != null
                  ? AppColors.accent
                  : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFile != null
                        ? selectedFile!.path.split('/').last
                        : 'Tap to select an audio track',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selectedFile != null)
                    const Text(
                      'MP3 / WAV / AAC supported',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }
}

// ── Karaoke Panel ───────────────────────────────────────────

class _KaraokePanel extends ConsumerWidget {
  const _KaraokePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocalMix = ref.watch(vocalMixProvider);
    final selectedFile = ref.watch(selectedFileProvider);
    final stemState = ref.watch(stemStateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelDescription(
            icon: '\uD83C\uDFA4',
            title: 'Choir & Karaoke Mode',
            subtitle:
                'Fade out the vocals and sing along to the pure instrumental track.',
          ),
          const SizedBox(height: 24),
          const Text(
            'VOCAL FADE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _NeonSlider(
            value: vocalMix,
            leftLabel: 'Instrumental Only',
            rightLabel: 'Full Vocals',
            onChanged: (v) =>
                ref.read(vocalMixProvider.notifier).state = v,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              vocalMix < 0.15
                  ? '\uD83C\uDFB8 Pure Instrumental'
                  : vocalMix > 0.85
                      ? '\uD83C\uDFA4 Full Vocals'
                      : '\uD83C\uDFB5 Blended Mix',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _ProcessButton(
            label: 'Split & Practice',
            icon: Icons.mic_external_on_rounded,
            isReady: selectedFile != null &&
                stemState.status != StemStatus.processing &&
                stemState.status != StemStatus.uploading,
            onTap: selectedFile != null
                ? () => ref
                    .read(stemStateProvider.notifier)
                    .splitTrack(selectedFile)
                : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── DJ Drop Panel ────────────────────────────────────────────

class _DjDropPanel extends ConsumerWidget {
  const _DjDropPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(selectedFileProvider);
    final stemState = ref.watch(stemStateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelDescription(
            icon: '\uD83C\uDF99',
            title: 'DJ Drop Mode',
            subtitle:
                'Strip the beat. Isolate a clean vocal stem for your next mix or drop.',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _StemChip(
                  label: 'Vocals',
                  icon: Icons.record_voice_over_rounded,
                  color: AppColors.accent,
                  active: true,
                ),
                const SizedBox(width: 12),
                const Icon(Icons.add,
                    color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 12),
                _StemChip(
                  label: 'Instruments',
                  icon: Icons.piano_rounded,
                  color: Colors.grey,
                  active: false,
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                _StemChip(
                  label: 'Vocal Stem',
                  icon: Icons.mic_rounded,
                  color: AppColors.accentViolet,
                  active: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _ProcessButton(
            label: 'Extract Vocal Drop',
            icon: Icons.flash_on_rounded,
            isReady: selectedFile != null &&
                stemState.status != StemStatus.processing &&
                stemState.status != StemStatus.uploading,
            onTap: selectedFile != null
                ? () => ref
                    .read(stemStateProvider.notifier)
                    .splitTrack(selectedFile)
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: state.status == StemStatus.error
                ? Colors.redAccent
                : AppColors.accent,
          ),
        ),
        child: _buildContent(),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildContent() {
    switch (state.status) {
      case StemStatus.uploading:
      case StemStatus.processing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.status == StemStatus.uploading
                  ? 'Uploading track...'
                  : 'Splitting audio stems...',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
            const Text(
              'Powered by Spleeter · Cached locally after split',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
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
                Text(
                  'Stems Ready — Cached Offline',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StemPlaybackRow(label: '\uD83C\uDFA4 Vocals', path: state.vocalPath),
            const SizedBox(height: 10),
            _StemPlaybackRow(
                label: '\uD83C\uDFB8 Instrumental',
                path: state.instrumentalPath),
          ],
        );
      case StemStatus.error:
        return Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.errorMessage ?? 'Something went wrong.',
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Shared Sub-Widgets ─────────────────────────────────────────

class _PanelDescription extends StatelessWidget {
  final String icon, title, subtitle;
  const _PanelDescription({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NeonSlider extends StatelessWidget {
  final double value;
  final String leftLabel, rightLabel;
  final ValueChanged<double> onChanged;

  const _NeonSlider({
    required this.value,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withOpacity(0.2),
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftLabel,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
              Text(rightLabel,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProcessButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isReady;
  final VoidCallback? onTap;

  const _ProcessButton({
    required this.label,
    required this.icon,
    required this.isReady,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isReady ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isReady
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet],
                )
              : null,
          color: isReady ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
          border: isReady ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isReady ? Colors.black : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isReady ? Colors.black : AppColors.textSecondary,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StemChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;

  const _StemChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,
            color: active ? color : Colors.grey.shade700, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? color : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StemPlaybackRow extends StatelessWidget {
  final String label;
  final String? path;

  const _StemPlaybackRow({required this.label, this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  fontSize: 13)),
          const Spacer(),
          if (path != null)
            const Icon(Icons.play_circle_filled_rounded,
                color: AppColors.accent, size: 28)
          else
            const Icon(Icons.hourglass_empty_rounded,
                color: AppColors.textSecondary, size: 22),
        ],
      ),
    );
  }
}
