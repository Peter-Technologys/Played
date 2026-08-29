import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../core/models/media_item.dart';

class FileInfoSheet extends StatelessWidget {
  const FileInfoSheet({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <_InfoRow>[
      _InfoRow('Title', item.title),
      _InfoRow('Type', item.isVideo ? 'Video' : 'Audio'),
      _InfoRow('Duration', item.formattedDuration),
      _InfoRow('File size', item.formattedSize),
      if ((item.artist ?? '').trim().isNotEmpty)
        _InfoRow('Artist', item.artist!.trim()),
      if ((item.album ?? '').trim().isNotEmpty)
        _InfoRow('Album', item.album!.trim()),
      _InfoRow('File name', item.fileName),
      _InfoRow('Location', item.filePath, monospace: true),
      _InfoRow('Added', _formatDate(item.addedAt)),
      if (item.lastPlayedAt != null)
        _InfoRow('Last played', _formatDate(item.lastPlayedAt!)),
    ];

    return FractionallySizedBox(
      heightFactor: .78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: scheme.primary, size: 21),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'File details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close details',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= AppDimensions.mediumMin;
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 18,
                    12,
                    wide ? 32 : 18,
                    36,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) => _DetailRow(
                    row: rows[index],
                    stacked: !wide,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Row(
              children: [
                Icon(
                  Icons.content_copy_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap the copy button on any value to copy it.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} · '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.monospace = false});

  final String label;
  final String value;
  final bool monospace;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.row, required this.stacked});

  final _InfoRow row;
  final bool stacked;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: row.value));
    HapticFeedback.selectionClick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${row.label} copied')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = SelectableText(
      row.value,
      style: TextStyle(
        fontFamily: row.monospace ? 'monospace' : 'Inter',
        fontSize: 13,
        height: 1.45,
        fontWeight: row.monospace ? FontWeight.w500 : FontWeight.w600,
        color: scheme.onSurface,
      ),
    );

    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: value),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Copy ${row.label.toLowerCase()}',
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Text(
              row.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: value),
          IconButton(
            tooltip: 'Copy ${row.label.toLowerCase()}',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
