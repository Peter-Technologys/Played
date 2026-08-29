import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/audio_session_service.dart';

/// Follow the OS setting automatically with [system].
enum AppThemeMode { dark, amoled, light, system }

class AppSettings {
  final AppThemeMode themeMode;
  final bool autoResume;
  final bool defaultBatterySaver;
  final bool shuffle;
  final bool nowPlayingNotification;
  final bool appLockEnabled;
  final bool hideVaultFromRecents;
  final List<String> scanFolders;
  final String language;
  final double playbackSpeed;
  final bool autoPip;
  final bool pauseDuringCalls;
  final bool autoLoadSubtitles;
  final bool searchHistory;
  final bool orientationLocked;
  final bool continuousPlayback;
  final int maxConcurrentDownloads;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.autoResume = true,
    this.defaultBatterySaver = false,
    this.shuffle = false,
    this.nowPlayingNotification = true,
    this.appLockEnabled = false,
    this.hideVaultFromRecents = true,
    this.scanFolders = const [],
    this.language = 'en',
    this.playbackSpeed = 1.0,
    this.autoPip = false,
    this.pauseDuringCalls = true,
    this.autoLoadSubtitles = true,
    this.searchHistory = true,
    this.orientationLocked = false,
    this.continuousPlayback = true,
    this.maxConcurrentDownloads = 2,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? autoResume,
    bool? defaultBatterySaver,
    bool? shuffle,
    bool? nowPlayingNotification,
    bool? appLockEnabled,
    bool? hideVaultFromRecents,
    List<String>? scanFolders,
    String? language,
    double? playbackSpeed,
    bool? autoPip,
    bool? pauseDuringCalls,
    bool? autoLoadSubtitles,
    bool? searchHistory,
    bool? orientationLocked,
    bool? continuousPlayback,
    int? maxConcurrentDownloads,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        autoResume: autoResume ?? this.autoResume,
        defaultBatterySaver:
            defaultBatterySaver ?? this.defaultBatterySaver,
        shuffle: shuffle ?? this.shuffle,
        nowPlayingNotification:
            nowPlayingNotification ?? this.nowPlayingNotification,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        hideVaultFromRecents:
            hideVaultFromRecents ?? this.hideVaultFromRecents,
        scanFolders: scanFolders ?? this.scanFolders,
        language: language ?? this.language,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        autoPip: autoPip ?? this.autoPip,
        pauseDuringCalls: pauseDuringCalls ?? this.pauseDuringCalls,
        autoLoadSubtitles: autoLoadSubtitles ?? this.autoLoadSubtitles,
        searchHistory: searchHistory ?? this.searchHistory,
        orientationLocked: orientationLocked ?? this.orientationLocked,
        continuousPlayback: continuousPlayback ?? this.continuousPlayback,
        maxConcurrentDownloads:
            maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      );

  static const _kTheme = 'settings_theme';
  static const _kAutoResume = 'settings_auto_resume';
  static const _kBatterySaver = 'settings_battery_saver';
  static const _kShuffle = 'settings_shuffle';
  static const _kNotification = 'settings_notification';
  static const _kAppLock = 'settings_app_lock';
  static const _kHideVault = 'settings_hide_vault';
  static const _kLanguage = 'settings_language';
  static const _kPlaybackSpeed = 'settings_playback_speed';
  static const _kAutoPip = 'settings_auto_pip';
  static const _kPauseCalls = 'settings_pause_calls';
  static const _kAutoSubtitles = 'settings_auto_subtitles';
  static const _kScanFolders = 'settings_scan_folders';
  static const _kSearchHistory = 'search_history';
  static const _kOrientationLocked = 'orientation_locked';
  static const _kContinuousPlayback = 'continuous_playback';
  static const _kMaxConcurrentDownloads = 'max_concurrent_downloads';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<AppSettings> load() async {
    final p = await _getPrefs();
    return AppSettings(
      // Existing users keep their saved choice. A fresh install follows the
      // device automatically instead of forcing OTYA into dark mode.
      themeMode: AppThemeMode.values[
          (p.getInt(_kTheme) ?? AppThemeMode.system.index)
              .clamp(0, AppThemeMode.values.length - 1)],
      autoResume: p.getBool(_kAutoResume) ?? true,
      defaultBatterySaver: p.getBool(_kBatterySaver) ?? false,
      shuffle: p.getBool(_kShuffle) ?? false,
      nowPlayingNotification: p.getBool(_kNotification) ?? true,
      appLockEnabled: p.getBool(_kAppLock) ?? false,
      hideVaultFromRecents: p.getBool(_kHideVault) ?? true,
      language: p.getString(_kLanguage) ?? 'en',
      playbackSpeed: p.getDouble(_kPlaybackSpeed) ?? 1.0,
      autoPip: p.getBool(_kAutoPip) ?? false,
      pauseDuringCalls: p.getBool(_kPauseCalls) ?? true,
      autoLoadSubtitles: p.getBool(_kAutoSubtitles) ?? true,
      scanFolders: p.getStringList(_kScanFolders) ?? const [],
      searchHistory: p.getBool(_kSearchHistory) ?? true,
      orientationLocked: p.getBool(_kOrientationLocked) ?? false,
      continuousPlayback: p.getBool(_kContinuousPlayback) ?? true,
      maxConcurrentDownloads: p.getInt(_kMaxConcurrentDownloads) ?? 2,
    );
  }

  Future<void> save() async {
    final p = await _getPrefs();
    await p.setInt(_kTheme, themeMode.index);
    await p.setBool(_kAutoResume, autoResume);
    await p.setBool(_kBatterySaver, defaultBatterySaver);
    await p.setBool(_kShuffle, shuffle);
    await p.setBool(_kNotification, nowPlayingNotification);
    await p.setBool(_kAppLock, appLockEnabled);
    await p.setBool(_kHideVault, hideVaultFromRecents);
    await p.setString(_kLanguage, language);
    await p.setDouble(_kPlaybackSpeed, playbackSpeed);
    await p.setBool(_kAutoPip, autoPip);
    await p.setBool(_kPauseCalls, pauseDuringCalls);
    await p.setBool(_kAutoSubtitles, autoLoadSubtitles);
    await p.setStringList(_kScanFolders, scanFolders);
    await p.setBool(_kSearchHistory, searchHistory);
    await p.setBool(_kOrientationLocked, orientationLocked);
    await p.setBool(_kContinuousPlayback, continuousPlayback);
    await p.setInt(_kMaxConcurrentDownloads, maxConcurrentDownloads);
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(AppSettings initial) : super(initial);

  Future<void> _update(AppSettings s) async {
    state = s;
    s.save().ignore();
  }

  void setThemeMode(AppThemeMode v) => _update(state.copyWith(themeMode: v));
  void setAutoResume(bool v) => _update(state.copyWith(autoResume: v));
  void setDefaultBatterySaver(bool v) =>
      _update(state.copyWith(defaultBatterySaver: v));
  void setShuffle(bool v) => _update(state.copyWith(shuffle: v));
  void setNowPlayingNotification(bool v) =>
      _update(state.copyWith(nowPlayingNotification: v));
  void setAppLock(bool v) => _update(state.copyWith(appLockEnabled: v));
  void setHideVaultFromRecents(bool v) =>
      _update(state.copyWith(hideVaultFromRecents: v));
  void setScanFolders(List<String> v) =>
      _update(state.copyWith(scanFolders: v));
  void setLanguage(String v) => _update(state.copyWith(language: v));
  void setPlaybackSpeed(double v) =>
      _update(state.copyWith(playbackSpeed: v));
  void setAutoPip(bool v) => _update(state.copyWith(autoPip: v));
  void setPauseDuringCalls(bool v) {
    _update(state.copyWith(pauseDuringCalls: v));
    AudioSessionService.instance.setPauseDuringCalls(v).ignore();
  }
  void setAutoLoadSubtitles(bool v) =>
      _update(state.copyWith(autoLoadSubtitles: v));
  void setSearchHistory(bool v) =>
      _update(state.copyWith(searchHistory: v));
  void setOrientationLocked(bool v) =>
      _update(state.copyWith(orientationLocked: v));
  void setContinuousPlayback(bool v) =>
      _update(state.copyWith(continuousPlayback: v));
  void setMaxConcurrentDownloads(int v) =>
      _update(state.copyWith(maxConcurrentDownloads: v));
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (_) => SettingsNotifier(const AppSettings()),
);

Future<AppSettings> loadSettingsForStartup() async {
  try {
    return await AppSettings.load();
  } catch (_) {
    return const AppSettings();
  }
}

final localeProvider = Provider<Locale>((ref) {
  final language = ref.watch(settingsProvider).language;
  return Locale(language);
});
