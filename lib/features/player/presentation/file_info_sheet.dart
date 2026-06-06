import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';

// ── File Info Sheet ─────────────────────────────────────────────

class FileInfoSheet extends StatelessWidget {
  final MediaItem item;
  const FileInfoSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _InfoRow('Title', item.title),
      _InfoRow('Type', item.isVideo ? 'Video' : 'Audio'),
      _InfoRow('Duration', item.formattedDuration),
      _InfoRow('File Size', item.formattedSize),
      _InfoRow('Artist', item.artist ?? 'Unknown'),
      _InfoRow('Album', item.album ?? 'Unknown'),
      _InfoRow('File Name', item.fileName),
      _InfoRow('Full Path', item.filePath),
      _InfoRow('Date Added', _fmtDate(item.addedAt)),
      if (item.lastPlayedAt != null)
        _InfoRow('Last Played', _fmtDate(item.lastPlayedAt!)),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text('File Info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'SpaceGrotesk',
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (_, i) => _RowWidget(row: rows[i]),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

class _RowWidget extends StatelessWidget {
  final _InfoRow row;
  const _RowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(row.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'SpaceGrotesk',
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: row.value));
                HapticFeedback.mediumImpact();
              },
              child: Text(row.value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'SpaceGrotesk',
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
