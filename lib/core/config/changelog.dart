import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Changelog config
//
// Single source of truth for What's New data.
// Import this file and use [changelog] wherever release notes are displayed.
// ─────────────────────────────────────────────────────────────────────────────

/// A single change item shown inside a [ChangeSection].
class ChangeItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const ChangeItem(this.icon, this.color, this.title, this.description);
}

/// A versioned release section containing a list of [ChangeItem]s.
class ChangeSection {
  final String version;
  final String date;
  final bool isLatest;
  final List<ChangeItem> items;

  const ChangeSection({
    required this.version,
    required this.date,
    required this.isLatest,
    required this.items,
  });
}

/// All changelog entries, newest first.
const List<ChangeSection> changelog = [
  ChangeSection(
    version: '1.4.0',
    date: 'July 2026',
    isLatest: true,
    items: [
      ChangeItem(
        Icons.play_circle_fill_rounded,
        AppColors.accent,
        'New Video Engine',
        'Migrated to media_kit — faster startup, hardware-accelerated, supports MKV/AVI/4K.',
      ),
      ChangeItem(
        Icons.wifi_tethering_rounded,
        AppColors.accentViolet,
        'Flash Share',
        'Pure-Dart HTTP file sharing — no Bluetooth pairing needed.',
      ),
      ChangeItem(
        Icons.lock_rounded,
        AppColors.accent,
        'Vault in Nav Bar',
        'One-tap access to your private vault from the bottom nav.',
      ),
      ChangeItem(
        Icons.construction_rounded,
        AppColors.accentViolet,
        'UI Refresh',
        'Readable dark theme, logo-only header, less crowded screens.',
      ),
      ChangeItem(
        Icons.system_update_rounded,
        AppColors.accent,
        'Auto Update Check',
        'In-app update checker now enabled by default.',
      ),
      ChangeItem(
        Icons.share_rounded,
        AppColors.accentViolet,
        'Share App',
        'Share the app download link directly from Settings.',
      ),
    ],
  ),
  ChangeSection(
    version: '1.2.0',
    date: 'June 2026',
    isLatest: false,
    items: [
      ChangeItem(
        Icons.video_library_rounded,
        AppColors.accent,
        'Video Thumbnails',
        'Real video frames shown in the grid.',
      ),
      ChangeItem(
        Icons.album_rounded,
        AppColors.accentViolet,
        'Album Art',
        'Real cover art from your music files.',
      ),
      ChangeItem(
        Icons.directions_car_rounded,
        AppColors.accent,
        'Car Mode',
        'Large-button layout for safe driving.',
      ),
      ChangeItem(
        Icons.lyrics_rounded,
        AppColors.accentViolet,
        'Offline Lyrics',
        'Lyrics cached locally after first fetch.',
      ),
      ChangeItem(
        Icons.subtitles_rounded,
        AppColors.accent,
        'Auto Subtitles',
        'Loads .srt/.ass automatically with videos.',
      ),
    ],
  ),
  ChangeSection(
    version: '1.1.0',
    date: 'May 2026',
    isLatest: false,
    items: [
      ChangeItem(
        Icons.queue_music_rounded,
        AppColors.accent,
        'Playlists',
        'Create, rename, reorder and play playlists.',
      ),
      ChangeItem(
        Icons.picture_in_picture_alt_rounded,
        AppColors.accentViolet,
        'PiP Auto-Mode',
        'Video floats when you leave the app.',
      ),
      ChangeItem(
        Icons.folder_special_rounded,
        AppColors.accent,
        'Full SD Card Access',
        'MANAGE_EXTERNAL_STORAGE support.',
      ),
    ],
  ),
];
