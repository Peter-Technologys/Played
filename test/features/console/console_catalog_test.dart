import 'package:flutter_test/flutter_test.dart';
import 'package:otya_player/features/console/console_catalog.dart';

void main() {
  test('console top-level sections are unique', () {
    final labels = otyaConsoleSections.map((section) => section.label).toList();
    expect(labels.toSet().length, labels.length);
  });

  test('console tools have one primary home', () {
    final owners = <String, String>{};

    for (final section in otyaConsoleSections) {
      for (final item in section.items) {
        final key = item.trim().toLowerCase();
        expect(
          owners.containsKey(key),
          isFalse,
          reason: '$item appears in both ${owners[key]} and ${section.label}',
        );
        owners[key] = section.label;
      }
    }
  });

  test('search is not a duplicate top-level destination', () {
    expect(
      otyaConsoleSections.any(
        (section) => section.label.toLowerCase() == 'search',
      ),
      isFalse,
    );
  });
}
