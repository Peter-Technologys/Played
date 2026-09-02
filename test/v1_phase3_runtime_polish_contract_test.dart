import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup settings are loaded once and shared with background bootstrap', () {
    final main = File('lib/main.dart').readAsStringSync();
    final app = File('lib/app/app.dart').readAsStringSync();
    final settings =
        File('lib/features/settings/settings_provider.dart').readAsStringSync();

    expect(app, contains('final savedSettings = await AppSettings.load();'));
    expect(app, contains('ref.read(settingsProvider.notifier).hydrate(savedSettings);'));
    expect(app, contains('ref.read(settingsProvider.notifier).hydrate(const AppSettings());'));
    expect(settings, contains('Future<AppSettings> get startupHydration'));
    expect(settings, contains('_startupHydration.complete(settings)'));
    expect(main, contains('await settingsNotifier.startupHydration'));
    expect(main, isNot(contains('AppSettings.load()')));
  });

  test('Me keeps only Transfer Files and Private as primary shortcuts', () {
    final source = File(
      'lib/features/my_space/presentation/my_space_hub_screen.dart',
    ).readAsStringSync();

    final quickStart = source.indexOf("_SectionLabel('Quick actions')");
    final secondaryStart =
        source.indexOf("_SectionLabel('Library & activity')", quickStart);
    expect(quickStart, greaterThanOrEqualTo(0));
    expect(secondaryStart, greaterThan(quickStart));

    final quick = source.substring(quickStart, secondaryStart);
    expect(quick, contains("title: 'Transfer'"));
    expect(quick, contains("title: 'Files'"));
    expect(quick, contains("title: 'Private'"));
    expect(quick, isNot(contains("title: 'Tools'")));
    expect(quick, isNot(contains("title: 'Playlists'")));
  });

  test('Me preserves secondary Playlists and avoids duplicate Help/About destinations', () {
    final source = File(
      'lib/features/my_space/presentation/my_space_hub_screen.dart',
    ).readAsStringSync();

    expect(source, contains("title: 'Playlists'"));
    expect(source, contains("context.push('/playlists')"));
    expect(source, contains("title: 'Tools'"));
    expect(source, contains("title: 'About Otya'"));
    expect(source, isNot(contains("title: 'Help'")));
  });

  test('Settings keeps playback controls separate from ordinary notification permission', () {
    final source = File(
      'lib/features/settings/presentation/settings_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains("title: 'Notification permission'"));
    expect(source, contains('Completed tasks, security notices and Otya updates'));
    expect(source, isNot(contains('Playback controls, completed tasks')));
    expect(source, contains("title: 'Next'"));
    expect(source, contains("title: 'About Otya'"));
  });

  test('About and update surfaces preserve official safe release behavior', () {
    final about = File(
      'lib/features/settings/presentation/about_screen.dart',
    ).readAsStringSync();
    final update = File('lib/core/widgets/update_dialog.dart').readAsStringSync();

    expect(about, contains("title: const Text('About Otya')"));
    expect(about, contains("label: 'Next'"));
    expect(about, contains("subject: 'Otya Problem Report'"));
    expect(about, contains("label: 'Share Otya'"));
    expect(about, contains("subject: 'Otya'"));
    expect(update, contains("uri.scheme != 'https'"));
    expect(update, contains('_officialHosts.contains(uri.host.toLowerCase())'));
    expect(update, contains('The app does not silently install packages'));
    expect(update, contains('const OtyaMark(size: 46)'));
    expect(update, isNot(contains('Color(0xFF8173F2)')));
  });

  test('ordinary notification taps accept local files or official HTTPS only', () {
    final source =
        File('lib/core/services/notification_service.dart').readAsStringSync();

    expect(source, contains("if (uri.scheme == 'file')"));
    expect(source, contains("uri.scheme != 'https'"));
    expect(source, contains("host == _officialHost || host.endsWith('.\$_officialHost')"));
    expect(source, isNot(contains("uri.scheme != 'https' && uri.scheme != 'http'")));
    expect(source, contains('Otya Tools — Progress'));
    expect(source, contains('Otya Tools — Complete'));
    expect(source, contains('Otya Tools — Error'));
    expect(source, isNot(contains('Now Playing controls, lock-screen playback')));
  });

  test('Next has one canonical live screen implementation', () {
    final entry = File('lib/features/ai/otya_support_screen.dart').readAsStringSync();

    expect(entry, contains("export 'otya_support_screen_v3.dart';"));
    expect(File('lib/features/ai/otya_support_screen_v3.dart').existsSync(), isTrue);
    expect(File('lib/features/ai/otya_support_screen_v2.dart').existsSync(), isFalse);
  });

  test('touched Phase 3 surfaces use canonical Otya casing', () {
    for (final path in [
      'lib/app/app.dart',
      'lib/features/my_space/presentation/my_space_hub_screen.dart',
      'lib/features/settings/settings_provider.dart',
      'lib/features/settings/presentation/settings_detail_screen.dart',
      'lib/features/settings/presentation/about_screen.dart',
      'lib/core/widgets/update_dialog.dart',
      'lib/core/services/notification_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("'OTYA'")), reason: path);
      expect(source, isNot(contains("'OTYA Account'")), reason: path);
      expect(source, isNot(contains("'About OTYA'")), reason: path);
      expect(source, isNot(contains('OTYA Player')), reason: path);
    }
  });
}
