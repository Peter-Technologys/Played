import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/models/media_item.dart';

// ── WhatsApp Trimmer Screen ─────────────────────────────────────

enum TrimStatus { idle, trimming, done, error }

final trimStatusProvider = StateProvider<TrimStatus>((_) => TrimStatus.idle);
final trimProgressProvider = StateProvider<double>((_) => 0.0);
final trimStartProvider = StateProvider<double>((_) => 0.0);
final trimEndProvider = StateProvider<double>((_) => 30.0);

class WhatsAppTrimmerScreen extends ConsumerWidget {
  final MediaItem mediaItem;
  const WhatsAppTrimmerScreen({super.key, required this.mediaItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status   = ref.watch(trimStatusProvider);
    final progress = ref.watch(trimProgressProvider);
    final start    = ref.watch(trimStartProvider);
    final end      = ref.watch(trimEndProvider);
    final duration = mediaItem.duration?.inSeconds.toDouble() ?? 60.0;

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
        title: const Text('WhatsApp Trimmer',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 18,
            )),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.accent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Trims video to 30s and compresses under 16MB for WhatsApp Status.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(mediaItem.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(mediaItem.formattedDuration,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Clip: ${_fmt(Duration(seconds: start.toInt()))} → ${_fmt(Duration(seconds: end.toInt()))}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('30s',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'SpaceGrotesk',
                        )),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (status == TrimStatus.trimming) ...
              [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Trimming & compressing...',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
              ],
            if (status == TrimStatus.done)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text('Saved to Downloads!',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SpaceGrotesk',
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: status == TrimStatus.trimming
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      ref.read(trimStatusProvider.notifier).state = TrimStatus.trimming;
                      ref.read(trimProgressProvider.notifier).state = 0;
                      final result = await FfmpegService.instance.extractAudio(
                        videoPath: mediaItem.filePath,
                        onProgress: (p) =>
                            ref.read(trimProgressProvider.notifier).state = p,
                      );
                      ref.read(trimStatusProvider.notifier).state =
                          result != null ? TrimStatus.done : TrimStatus.error;
                    },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: status != TrimStatus.trimming
                      ? const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentViolet])
                      : null,
                  color: status == TrimStatus.trimming ? AppColors.surface : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: status != TrimStatus.trimming
                      ? [BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  status == TrimStatus.trimming
                      ? 'Processing...'
                      : '\uD83D\uDCF1  Trim for WhatsApp Status',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: status == TrimStatus.trimming
                        ? AppColors.textSecondary
                        : Colors.black,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
              fontFamily: 'SpaceGrotesk',
            )),
        Text('$m:$s',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
