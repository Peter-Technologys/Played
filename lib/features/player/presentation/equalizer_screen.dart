import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/services/media_dsp_service.dart';
import '../../../core/services/playback_coordinator.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';

/// OTYA Sound Tuner.
///
/// Equalization is applied inside the active MediaKit/libmpv player. It does
/// not use Android's deprecated session-0/global Equalizer effect and therefore
/// cannot intentionally retune audio from other apps.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final _dsp = MediaDspService.instance;

  List<double> _gains = List<double>.filled(MediaDspService.frequencies.length, 0);
  String _preset = 'Flat';
  String? _status;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gains = await _dsp.loadGains();
    final preset = await _dsp.loadPreset();
    if (!mounted) return;
    setState(() {
      _gains = gains;
      _preset = preset;
      _loading = false;
    });
  }

  Future<void> _apply({String? preset}) async {
    if (_applying) return;
    setState(() {
      _applying = true;
      _status = null;
    });

    final name = preset ?? 'Custom';
    await _dsp.save(gains: _gains, preset: name);

    final player = PlaybackCoordinator.instance.activePlayer;
    if (player == null) {
      if (!mounted) return;
      setState(() {
        _preset = name;
        _applying = false;
        _status = 'Saved. Start playing music or video to hear this tuning.';
      });
      return;
    }

    final applied = await _dsp.apply(player, _gains);
    if (!mounted) return;
    setState(() {
      _preset = name;
      _applying = false;
      _status = applied
          ? 'Applied to the active OTYA player.'
          : 'Sound tuning is unavailable for this playback engine.';
    });
  }

  Future<void> _choosePreset(String name) async {
    final values = MediaDspService.presets[name];
    if (values == null) return;
    setState(() {
      _gains = List<double>.from(values);
      _preset = name;
    });
    await _apply(preset: name);
  }

  void _setBand(int index, double value) {
    setState(() {
      final next = List<double>.from(_gains);
      next[index] = value;
      _gains = next;
      _preset = 'Custom';
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return WallpaperScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Sound Tuner',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _loading || _applying
                ? null
                : () => _choosePreset('Flat'),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2.5,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space16,
                  AppDimensions.space8,
                  AppDimensions.space16,
                  AppDimensions.space32,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: .18),
                            ),
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: AppColors.accent,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tune OTYA, not your whole phone',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Five-band EQ runs inside the active OTYA player. Your preset is remembered and reapplied when playback changes.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Presets',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MediaDspService.presets.keys.map((name) {
                      final selected = _preset == name;
                      return ChoiceChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: _applying
                            ? null
                            : (value) {
                                if (value) _choosePreset(name);
                              },
                        showCheckmark: false,
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.cardOf(context),
                        side: BorderSide(
                          color: selected
                              ? AppColors.accent
                              : AppColors.borderOf(context),
                        ),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Column(
                      children: List.generate(_gains.length, (index) {
                        final value = _gains[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 62,
                                child: Text(
                                  MediaDspService.labels[index],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppColors.accent,
                                    inactiveTrackColor:
                                        AppColors.borderOf(context),
                                    thumbColor: AppColors.accent,
                                    overlayColor: AppColors.accent
                                        .withValues(alpha: .14),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: value,
                                    min: -10,
                                    max: 10,
                                    divisions: 40,
                                    label:
                                        '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
                                    onChanged: _applying
                                        ? null
                                        : (next) => _setBand(index, next),
                                    onChangeEnd: _applying
                                        ? null
                                        : (_) => _apply(),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 58,
                                child: Text(
                                  '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_status != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            size: 19,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _status!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _applying ? null : _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _applying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.graphic_eq_rounded),
                    label: Text(_applying ? 'Applying…' : 'Apply tuning'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tip: extreme boosts can distort already-loud recordings. OTYA limits each band to ±10 dB.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
