import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account switch clears stale email and avatar metadata', () {
    final source =
        File('lib/core/services/auth_provider.dart').readAsStringSync();

    expect(source, contains("await prefs.remove('otya_user_email');"));
    expect(source, contains("await prefs.remove('otya_user_avatar');"));
    expect(source, contains('final resolvedPhotoUrl = photoUrl?.trim();'));
    expect(source, contains('resolvedEmail.trim().isNotEmpty'));
  });
}
