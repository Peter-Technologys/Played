import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release configuration contract', () {
    test('mobile source does not contain server-only secret identifiers', () {
      final roots = <Directory>[
        Directory('lib'),
        Directory('android/app/src/main'),
      ];

      final forbidden = <RegExp>[
        RegExp(r'RESEND_API_KEY'),
        RegExp(r'AUTH_JWT_SECRET'),
        RegExp(r'INTERNAL_SECRET'),
        RegExp(r'TELEGRAM_LOGIN_CLIENT_SECRET'),
        RegExp(r'GOOGLE_CLIENT_SECRET'),
        RegExp(r'SPOTIFY_CLIENT_SECRET'),
        RegExp(r'OPENAI_API_KEY'),
        RegExp(r'GEMINI_API_KEY'),
        RegExp(r'GROQ_API_KEY'),
        RegExp(r'ANTHROPIC_API_KEY'),
        RegExp(r'CF_API_TOKEN'),
        RegExp(r'BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY'),
        RegExp(r'\bsk-[A-Za-z0-9_-]{16,}'),
      ];

      final findings = <String>[];
      for (final root in roots) {
        if (!root.existsSync()) continue;
        for (final entity in root.listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path.replaceAll('\\', '/');
          if (!_isTextSource(path)) continue;
          final text = entity.readAsStringSync();
          for (final pattern in forbidden) {
            if (pattern.hasMatch(text)) {
              findings.add('$path matched ${pattern.pattern}');
            }
          }
        }
      }

      expect(
        findings,
        isEmpty,
        reason: 'Server credentials must never be compiled into the Otya APK.\n'
            '${findings.join('\n')}',
      );
    });

    test('release source has no cleartext or development backend URLs', () {
      final root = Directory('lib');
      final findings = <String>[];
      final forbiddenEverywhere = <RegExp>[
        RegExp(r'localhost', caseSensitive: false),
        RegExp(r'127\.0\.0\.1'),
        RegExp(r'\.workers\.dev', caseSensitive: false),
      ];
      final cleartext = RegExp(r'http://', caseSensitive: false);

      if (root.existsSync()) {
        for (final entity in root.listSync(recursive: true, followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll('\\', '/');
          final text = entity.readAsStringSync();

          // OTYA Transfer is intentionally local-network only and uses
          // authenticated cleartext HTTP between nearby devices. The transfer
          // implementation has its own contract tests that reject non-local
          // addresses, so the production-backend URL check must not treat this
          // local protocol as a remote cleartext backend endpoint.
          final isLocalTransferSource =
              path.startsWith('lib/features/transfer/');
          if (!isLocalTransferSource && cleartext.hasMatch(text)) {
            findings.add('$path matched ${cleartext.pattern}');
          }

          for (final pattern in forbiddenEverywhere) {
            if (pattern.hasMatch(text)) {
              findings.add('$path matched ${pattern.pattern}');
            }
          }
        }
      }

      expect(
        findings,
        isEmpty,
        reason: 'Production app source must not contain development or remote '
            'cleartext backend endpoints.\n${findings.join('\n')}',
      );
    });

    test('changeable public values are centralized in Environment', () {
      final env = File('lib/core/config/environment.dart').readAsStringSync();

      expect(env, contains("String.fromEnvironment(\n    'WORKER_URL'"));
      expect(env, contains("String.fromEnvironment(\n    'PUBLIC_SITE_URL'"));
      expect(env, contains("String.fromEnvironment(\n    'SUPPORT_EMAIL'"));
      expect(env, contains("String.fromEnvironment(\n    'SPOTIFY_CLIENT_ID'"));
      expect(env, contains("String.fromEnvironment(\n    'SPOTIFY_REDIRECT_URI'"));
    });

    test('localization generation remains enabled', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final l10n = File('l10n.yaml').readAsStringSync();

      expect(pubspec, contains('generate: true'));
      expect(pubspec, contains('flutter_localizations:'));
      expect(l10n, contains('arb-dir: lib/l10n'));
      expect(File('lib/l10n/app_en.arb').existsSync(), isTrue);
      expect(File('lib/l10n/app_lg.arb').existsSync(), isTrue);
    });
  });
}

bool _isTextSource(String path) {
  return path.endsWith('.dart') ||
      path.endsWith('.xml') ||
      path.endsWith('.gradle') ||
      path.endsWith('.properties') ||
      path.endsWith('.json');
}
