import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RepeatMode { off, one, all }
enum AppThemeMode { dark, amoled, light }

class AppSettings {
  final AppThemeMode themeMode;
  final bool autoResume;
  final bool defaultBatterySaver;
  final RepeatMode repeatMode;
  final bool shuffle;
  final double crossfadeDuration;
  final bool skipSilence;
  final bool gaplessPlayback;
  final bool nowPlayingNotification;
  final bool appLockEnabled;
  final bool hideVaultFromRecents;
  final List<String> scanFolders;
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
        defaultBatterySaver: defaultBatterySaver ?? this.defaultBatterySaver,
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

  // ── SharedPreferences keys ──
  static const _kTheme        = 'settings_theme';
  static const _kAutoResume   = 'settings_auto_resume';
  static const _kBatterySaver = 'settings_battery_saver';
  static const _kRepeat       = 'settings_repeat';
  static const _kShuffle      = 'settings_shuffle';
  static const _kCrossfade    = 'settings_crossfade';
  static const _kSkipSilence  = 'settings_skip_silence';
  static const _kGapless      = 'settings_gapless';
  static const _kNotification = 'settings_notification';
  static const _kAppLock      = 'settings_app_lock';
  static const _kHideVault    = 'settings_hide_vault';
  static const _kLanguage     = 'settings_language';

  /// Load all settings from SharedPreferences.
  /// Called once in main() before runApp() so UI starts with correct values.
  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: AppThemeMode.values[
          (p.getInt(_kTheme) ?? AppThemeMode.dark.index)
              .clamp(0, AppThemeMode.values.length - 1)],
      autoResume:             p.getBool(_kAutoResume)   ?? true,
      defaultBatterySaver:    p.getBool(_kBatterySaver) ?? false,
      repeatMode: RepeatMode.values[
          (p.getInt(_kRepeat) ?? RepeatMode.off.index)
              .clamp(0, RepeatMode.values.length - 1)],
      shuffle:                p.getBool(_kShuffle)      ?? false,
      crossfadeDuration:      p.getDouble(_kCrossfade)  ?? 0.0,
      skipSilence:            p.getBool(_kSkipSilence)  ?? false,
      gaplessPlayback:        p.getBool(_kGapless)      ?? true,
      nowPlayingNotification: p.getBool(_kNotification) ?? true,
      appLockEnabled:         p.getBool(_kAppLock)      ?? false,
      hideVaultFromRecents:   p.getBool(_kHideVault)    ?? true,
      language:               p.getString(_kLanguage)   ?? 'en',
    );
  }

  /// Persist current settings to SharedPreferences.
  /// Called automatically by SettingsNotifier on every change.
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTheme,         themeMode.index);
    await p.setBool(_kAutoResume,    autoResume);
    await p.setBool(_kBatterySaver,  defaultBatterySaver);
    await p.setInt(_kRepeat,         repeatMode.index);
    await p.setBool(_kShuffle,       shuffle);
    await p.setDouble(_kCrossfade,   crossfadeDuration);
    await p.setBool(_kSkipSilence,   skipSilence);
    await p.setBool(_kGapless,       gaplessPlayback);
    await p.setBool(_kNotification,  nowPlayingNotification);
    await p.setBool(_kAppLock,       appLockEnabled);
    await p.setBool(_kHideVault,     hideVaultFromRecents);
    await p.setString(_kLanguage,    language);
  }
}

// ── Notifier: persists every change to SharedPreferences ──
class SettingsNotifier extends StateNotifier<AppSettings> {
  // Accepts initial settings pre-loaded from SharedPreferences in main()
  SettingsNotifier(AppSettings initial) : super(initial);

  Future<void> _update(AppSettings s) async {
    state = s;
    await s.save();
  }

  void setThemeMode(AppThemeMode v)       => _update(state.copyWith(themeMode: v));
  void setAutoResume(bool v)              => _update(state.copyWith(autoResume: v));
  void setDefaultBatterySaver(bool v)     => _update(state.copyWith(defaultBatterySaver: v));
  void setRepeatMode(RepeatMode v)        => _update(state.copyWith(repeatMode: v));
  void setShuffle(bool v)                 => _update(state.copyWith(shuffle: v));
  void setCrossfade(double v)             => _update(state.copyWith(crossfadeDuration: v));
  void setSkipSilence(bool v)             => _update(state.copyWith(skipSilence: v));
  void setGaplessPlayback(bool v)         => _update(state.copyWith(gaplessPlayback: v));
  void setNowPlayingNotification(bool v)  => _update(state.copyWith(nowPlayingNotification: v));
  void setAppLock(bool v)                 => _update(state.copyWith(appLockEnabled: v));
  void setHideVaultFromRecents(bool v)    => _update(state.copyWith(hideVaultFromRecents: v));
  void setScanFolders(List<String> v)     => _update(state.copyWith(scanFolders: v));
  void setLanguage(String v)              => _update(state.copyWith(language: v));
}

// Seeded in main() with values loaded from SharedPreferences
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (_) => SettingsNotifier(const AppSettings()),
);
