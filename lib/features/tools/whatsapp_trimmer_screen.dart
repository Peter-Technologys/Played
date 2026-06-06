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
