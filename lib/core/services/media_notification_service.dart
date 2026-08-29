import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'album_art_service.dart';
import 'audio_handler.dart';
import 'notification_service.dart';
import 'shared_notification_plugin.dart';

/// Owns system Now Playing metadata for notification shade, lock screen,
/// Bluetooth/headset controls and Android media surfaces.
class MediaNotificationService {
  MediaNotificationService._();
  static final MediaNotificationService instance = MediaNotificationService._();

  bool _initialized = false;
  bool _permissionChecked = false;
