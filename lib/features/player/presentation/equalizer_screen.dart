import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';

// ── Provider ───────────────────────────────────────────────class EqBand {
  final String label;
  final double gain; // -12 to +12 dB
  const EqBand({required this.label, required this.gain});
  EqBand copyWith({double? gain}) =>
      EqBand(label: label, gain: gain ?? this.gain);
}

class EqState {
  final List<EqBand> bands;
  final String preset;
  const EqState({required this.bands, required this.preset});
  EqState copyWith({List<EqBand>? bands, String? preset}) =>
      EqState(bands: bands ?? this.bands, preset: preset ?? this.preset);
}

class EqNotifier extends StateNotifier<EqState> {
  EqNotifier()
      : super(EqState(
          preset: 'Flat',
          bands: const [
            EqBand(label: '60Hz', gain: 0),
            EqBand(label: '230Hz', gain: 0),
            EqBand(label: '910Hz', gain: 0),
            EqBand(label: '3.6kHz', gain: 0),
            EqBand(label: '14kHz', gain: 0),
          ],
        ));

  static const Map<String, List<double>> _presets = {
    'Flat':         [0, 0, 0, 0, 0],
    'Bass Boost':   [8, 5, 0, -2, -3],
    'Vocal Clarity':[0, -2, 4, 5, 3],
    'Night Mode':   [-4, -2, 0, -3, -5],
    'Pop':          [2, 1, 0, 2, 3],
    'Hip-Hop':      [6, 4, 0, 2, 1],
  };

  void setBand(int index, double gain) {
    final updated = List<EqBand>.from(state.bands);
    updated[index] = updated[index].copyWith(gain: gain);
    state = state.copyWith(bands: updated, preset: 'Custom');
  }

  void applyPreset(String name) {
    final gains = _presets[name];
    if (gains == null) return;
    final updated = List.generate(
      state.bands.length,
      (i) => state.bands[i].copyWith(gain: gains[i]),
    );
    state = state.copyWith(bands: updated, preset: name);
  }

  List<String> get presetNames => _presets.keys.toList();
}

final eqProvider =
    StateNotifierProvider<EqNotifier, EqState>((_) => EqNotifier());

// ── Equalizer Screen ───────────────────────────────────────────

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(eqProvider);
    final notifier = ref.read(eqProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Equalizer',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 18,
            )),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(eq.preset,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SpaceGrotesk',
                    )),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Preset chips ───────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: notifier.presetNames.map((name) {
                final active = eq.preset == name;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    notifier.applyPreset(name);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accent
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                    child: Text(name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.black
                              : AppColors.textSecondary,
                          fontFamily: 'SpaceGrotesk',
                        )),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // ── EQ Bands ───────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(eq.bands.length, (i) {
                  final band = eq.bands[i];
                  return _BandSlider(
                    band: band,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      notifier.setBand(i, v);
                    },
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Reset button ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                notifier.applyPreset('Flat');
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: const Text('Reset to Flat',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFamily: 'SpaceGrotesk',
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final EqBand band;
  final ValueChanged<double> onChanged;
  const _BandSlider({required this.band, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${band.gain > 0 ? '+' : ''}${band.gain.toStringAsFixed(0)}dB',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: band.gain == 0
                ? AppColors.textSecondary
                : AppColors.accent,
            fontFamily: 'SpaceGrotesk',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withOpacity(0.15),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: band.gain,
                min: -12,
                max: 12,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(band.label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
