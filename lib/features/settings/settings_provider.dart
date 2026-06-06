import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  final bool autoResume;
  final bool defaultBatterySaver;
  final bool appLockEnabled;
  final String language;

  const AppSettings({
    this.autoResume = true,
    this.defaultBatterySaver = false,
    this.appLockEnabled = false,
    this.language = 'en',
  });

  AppSettings copyWith({
    bool? autoResume,
    bool? defaultBatterySaver,
    bool? appLockEnabled,
    String? language,
  }) =>
      AppSettings(
        autoResume: autoResume ?? this.autoResume,
        defaultBatterySaver:
            defaultBatterySaver ?? this.defaultBatterySaver,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        language: language ?? this.language,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setAutoResume(bool v) =>
      state = state.copyWith(autoResume: v);
  void setDefaultBatterySaver(bool v) =>
      state = state.copyWith(defaultBatterySaver: v);
  void setAppLock(bool v) =>
      state = state.copyWith(appLockEnabled: v);
  void setLanguage(String v) =>
      state = state.copyWith(language: v);
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (_) => SettingsNotifier(),
);
