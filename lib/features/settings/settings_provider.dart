import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RepeatMode { off, one, all }
enum AppThemeMode { dark, amoled, light }

class AppSettings {
  // Appearance
  final AppThemeMode themeMode;

  // Playback
  final bool autoResume;
  final bool defaultBatterySaver;
  final RepeatMode repeatMode;
  final bool shuffle;
  final double crossfadeDuration; // seconds 0–5
  final bool skipSilence;
  final bool gaplessPlayback;

  // Notifications
  final bool nowPlayingNotification;

  // Privacy & Security
  final bool appLockEnabled;
  final bool hideVaultFromRecents;

  // Storage
  final List<String> scanFolders;

  // Language
  final String language;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.autoResume = true,
    this.defaultBatterySaver = false,
    this.repeatMode = RepeatMode.off,
    this.shuffle = false,
    this.crossfadeDuration = 0.0,
    this.skipSilence = false,
    this.gaplessPlayback = true,
    this.nowPlayingNotification = true,
    this.appLockEnabled = false,
    this.hideVaultFromRecents = true,
    this.scanFolders = const [],
    this.language = 'en',
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? autoResume,
    bool? defaultBatterySaver,
    RepeatMode? repeatMode,
    bool? shuffle,
    double? crossfadeDuration,
    bool? skipSilence,
    bool? gaplessPlayback,
    bool? nowPlayingNotification,
    bool? appLockEnabled,
    bool? hideVaultFromRecents,
    List<String>? scanFolders,
    String? language,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        autoResume: autoResume ?? this.autoResume,
        defaultBatterySaver:
            defaultBatterySaver ?? this.defaultBatterySaver,
        repeatMode: repeatMode ?? this.repeatMode,
        shuffle: shuffle ?? this.shuffle,
        crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
        skipSilence: skipSilence ?? this.skipSilence,
        gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
        nowPlayingNotification:
            nowPlayingNotification ?? this.nowPlayingNotification,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        hideVaultFromRecents:
            hideVaultFromRecents ?? this.hideVaultFromRecents,
        scanFolders: scanFolders ?? this.scanFolders,
        language: language ?? this.language,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setThemeMode(AppThemeMode v) =>
      state = state.copyWith(themeMode: v);
  void setAutoResume(bool v) =>
      state = state.copyWith(autoResume: v);
  void setDefaultBatterySaver(bool v) =>
      state = state.copyWith(defaultBatterySaver: v);
  void setRepeatMode(RepeatMode v) =>
      state = state.copyWith(repeatMode: v);
  void setShuffle(bool v) => state = state.copyWith(shuffle: v);
  void setCrossfade(double v) =>
      state = state.copyWith(crossfadeDuration: v);
  void setSkipSilence(bool v) =>
      state = state.copyWith(skipSilence: v);
  void setGaplessPlayback(bool v) =>
      state = state.copyWith(gaplessPlayback: v);
  void setNowPlayingNotification(bool v) =>
      state = state.copyWith(nowPlayingNotification: v);
  void setAppLock(bool v) =>
      state = state.copyWith(appLockEnabled: v);
  void setHideVaultFromRecents(bool v) =>
      state = state.copyWith(hideVaultFromRecents: v);
  void setScanFolders(List<String> v) =>
      state = state.copyWith(scanFolders: v);
  void setLanguage(String v) =>
      state = state.copyWith(language: v);
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (_) => SettingsNotifier(),
);
