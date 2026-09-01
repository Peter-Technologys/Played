import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public product identity is Otya with Next as assistant', () {
    final readme = File('README.md').readAsStringSync();
    final about = File(
      'lib/features/settings/presentation/about_screen.dart',
    ).readAsStringSync();

    expect(readme, contains('# Otya'));
    expect(readme, contains('**Next** is the assistant inside Otya'));
    expect(about, contains("label: 'Next'"));
    expect(about, contains("label: 'Otya website'"));
    expect(about, contains("label: 'Terms of Service'"));
    expect(about, isNot(contains("label: 'Ask OTYA'")));
    expect(about, isNot(contains("label: 'OTYA website'")));
  });

  test('current docs do not present the Played 2024 policy as Otya policy', () {
    final currentPolicy = File('docs/PRIVACY_POLICY.md').readAsStringSync();
    final archivedPolicy = File(
      'docs/archive/PLAYED_PRIVACY_POLICY_2024.md',
    ).readAsStringSync();

    expect(currentPolicy, contains('Otya Privacy Policy — release preparation notice'));
    expect(currentPolicy, contains('not the final public Privacy Policy'));
    expect(currentPolicy, contains('PRIVACY_DATA_INVENTORY.md'));
    expect(archivedPolicy, contains('Historical document. Not the current Otya Privacy Policy.'));
    expect(archivedPolicy, contains('Privacy Policy — Played'));
  });

  test('security policy describes the current v1 acceptance state', () {
    final security = File('SECURITY.md').readAsStringSync();

    expect(security, contains('Otya `1.0.0+1`'));
    expect(security, contains('Otya Private'));
    expect(security, contains('Transfer local-network authorization'));
    expect(security, isNot(contains('current source version is `1.6.0+10`')));
    expect(security, isNot(contains('Safe/vault encryption')));
    expect(security, isNot(contains('Beam local transfer')));
  });

  test('public surface governance separates user, legal and engineering docs', () {
    final governance = File(
      'docs/PUBLIC_SURFACE_GOVERNANCE.md',
    ).readAsStringSync();

    expect(governance, contains('One source of truth per kind of information'));
    expect(governance, contains('Help Center'));
    expect(governance, contains('Account/data deletion'));
    expect(governance, contains('Developer docs'));
    expect(governance, contains('Engineering internals'));
    expect(governance, contains('Public truth is part of product quality'));
  });
}
