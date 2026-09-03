import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smart Search persists capped local history only when enabled', () {
    final search =
        File('lib/features/search/smart_search_sheet.dart').readAsStringSync();
    final settings =
        File('lib/features/settings/settings_provider.dart').readAsStringSync();

    expect(search, contains("static const _historyKey = 'otya_search_history';"));
    expect(search, contains('static const _historyLimit = 8;'));
    expect(search, contains('settingsProvider).searchHistory'));
    expect(search, contains('prefs.setStringList(_historyKey, updated)'));
    expect(search, contains('RECENT SEARCHES'));
    expect(search, contains('onClearRecent'));
    expect(settings, contains("_searchHistoryDataKey = 'otya_search_history'"));
    expect(settings, contains('if (!v) unawaited(_clearSavedSearchHistory());'));
  });
}
