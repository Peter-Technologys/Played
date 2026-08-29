import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/models/media_item.dart';

enum TrimStatus { idle, trimming, done, error }

final trimStatusProvider = StateProvider<TrimStatus>((_) => TrimStatus.idle);
final trimProgressProvider = StateProvider<double>((_) => 0.0);
final trimStartProvider = StateProvider<double>((_) => 0.0);
final trimEndProvider = StateProvider<double>((_) => 30.0);

/// Historical class name kept for route compatibility. User-facing naming is
/// simply OTYA Trim / Trim video.
class WhatsAppTrimmerScreen extends ConsumerWidget {
  final MediaItem mediaItem;
  const WhatsAppTrimmerScreen({super.key, required this.mediaItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(trimStatusProvider);
    final progress = ref.watch(trimProgressProvider);
    final start = ref.watch(trimStartProvider);
    final end = ref.watch(trimEndProvider);
    final duration = mediaItem.duration?.inSeconds.toDouble() ?? 60.0;
    final primary = AppColors.textPrimaryOf(context);
    final secondary = Theme.of(context).colorScheme.onSurface.withValues(alpha: .58);
    final card = AppColors.cardOf(context);
    final border = AppColors.borderOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Trim video')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create a 30-second clip locally. OTYA trims the original video without uploading it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                mediaItem.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  fontFamily: 'Inter',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                mediaItem.formattedDuration,
                style: TextStyle(fontSize: 12, color: secondary),
              ),
              const SizedBox(height: 32),
              _RangeLabel(
                label: 'Start',
                value: Duration(seconds: start.toInt()),
              ),
              Slider(
                value: start,
                min: 0,
                max: (duration - 30).clamp(0, duration),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  ref.read(trimStartProvider.notifier).state = v;
                  ref.read(trimEndProvider.notifier).state =
                      (v + 30).clamp(0, duration);
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_fmt(Duration(seconds: start.toInt()))}  →  ${_fmt(Duration(seconds: end.toInt()))}',
                        style: TextStyle(
                          fontSize: 13,
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '30 sec',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (status == TrimStatus.trimming) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accent,
                    ),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Creating local clip…',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 16),
              ],
              if (status == TrimStatus.done)
                _StatusCard(
                  icon: Icons.check_circle_rounded,
                  text: 'Clip created and added back to your media library',
                  color: AppColors.success,
                ),
              if (status == TrimStatus.error)
                _StatusCard(
                  icon: Icons.error_outline_rounded,
                  text: 'Could not create the clip. Try again.',
                  color: AppColors.error,
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: status == TrimStatus.trimming
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          ref.read(trimStatusProvider.notifier).state =
                              TrimStatus.trimming;
                          ref.read(trimProgressProvider.notifier).state = 0;
                          final result = await FfmpegService.instance.trimVideo(
                            videoPath: mediaItem.filePath,
                            startSec: start,
                            endSec: end,
                            onProgress: (p) => ref
                                .read(trimProgressProvider.notifier)
                                .state = p,
                          );
                          ref.read(trimStatusProvider.notifier).state =
                              result != null
                                  ? TrimStatus.done
                                  : TrimStatus.error;
                        },
                  icon: Icon(
                    status == TrimStatus.trimming
                        ? Icons.hourglass_top_rounded
                        : Icons.content_cut_rounded,
                  ),
                  label: Text(
                    status == TrimStatus.trimming
                        ? 'Processing…'
                        : 'Create 30-second clip',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatusCard({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      );
}

class _RangeLabel extends StatelessWidget {
  final String label;
  final Duration value;
  const _RangeLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: .58),
            letterSpacing: .6,
            fontFamily: 'Inter',
          ),
        ),
        Text(
          '$m:$s',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
