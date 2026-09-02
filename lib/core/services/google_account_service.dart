import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account_link_service.dart';
import 'auth_service.dart';
import 'backup_service.dart';

/// Google identity + private Drive App Folder integration.
///
/// Basic Google Sign-In requests identity only. The narrower Drive App Data
/// permission is requested lazily when the user explicitly backs up, restores,
/// or deletes a backup. Otya never stores the Google OAuth access token on disk.
/// Otya account tokens remain in Android Keystore via [AuthService].
class GoogleAccountService {
  GoogleAccountService._();
  static final GoogleAccountService instance = GoogleAccountService._();

  static const String _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '82776565585-obr8k53b8n6djsggissv8qne81cm3u5u.apps.googleusercontent.com',
  );

  static const String _driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  late final GoogleSignIn _google = GoogleSignIn(
    scopes: const <String>[
      'email',
      'profile',
    ],
    serverClientId: _webClientId,
  );

  GoogleSignInAccount? _account;
  String? _driveAccessToken;

  bool get isConfigured => _webClientId.isNotEmpty;
  String? get email => _account?.email;
  bool get hasGoogleSession => _account != null;

  Future<AuthResult> signInAndAuthenticate({
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool marketingConsent = false,
  }) async {
    try {
      final account = await _google.signIn();
      if (account == null) {
        return const AuthResult(ok: false, error: 'Google Sign-In was cancelled.');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const AuthResult(
          ok: false,
          error: 'Google could not verify this app installation. Please update Otya and try again.',
        );
      }

      // There is one Otya identity model. If the device already has a valid
      // Otya session, Google is linked to that current Otya ID. A signed-out
      // device may use the create-or-login Google endpoint. Drive permission is
      // deliberately not part of either identity path.
      final hasOtyaSession = await AuthService.instance.checkIsLoggedIn();
      final result = hasOtyaSession
          ? await AccountLinkService.instance.linkGoogle(idToken)
          : await AuthService.instance.loginWithGoogle(
              idToken,
              termsAccepted: termsAccepted,
              privacyAccepted: privacyAccepted,
              marketingConsent: marketingConsent,
            );

      if (result.ok) {
        _account = account;
        _driveAccessToken = null;
      }
      return result;
    } on PlatformException catch (error) {
      debugPrint(
        '[GoogleAccount] sign-in platform failure: code=${error.code}, '
        'detailsType=${error.details.runtimeType}',
      );
      return AuthResult(ok: false, error: _friendlyPlatformError(error));
    } catch (error) {
      debugPrint('[GoogleAccount] sign-in failed: ${error.runtimeType}');
      return const AuthResult(
        ok: false,
        error: 'Google Sign-In could not be completed. Check your connection and try again.',
      );
    }
  }

  String _friendlyPlatformError(PlatformException error) {
    final code = error.code.toLowerCase();
    final details = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();

    if (code.contains('network') || details.contains('network')) {
      return 'Google Sign-In needs an internet connection. Check your connection and try again.';
    }
    if (code.contains('cancel')) {
      return 'Google Sign-In was cancelled.';
    }
    if (details.contains('10') ||
        details.contains('developer_error') ||
        details.contains('developer error')) {
      return 'Google could not verify this signed Otya build. Check the Android OAuth package name and SHA fingerprint for this signing key.';
    }
    if (code.contains('sign_in_failed')) {
      return 'Google could not verify this Otya installation. Please update the app and try again.';
    }
    return 'Google Sign-In could not be completed. Please try again.';
  }

  Future<bool> restoreSession() async {
    try {
      final account = await _google.signInSilently();
      if (account == null) return false;
      _account = account;
      _driveAccessToken = null;
      return true;
    } catch (error) {
      debugPrint('[GoogleAccount] silent restore failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<String?> _freshDriveToken() async {
    if (_account == null) {
      await restoreSession();
    }
    final account = _account;
    if (account == null) return null;

    try {
      final granted = await _google.requestScopes(const <String>[
        _driveAppDataScope,
      ]);
      if (!granted) return null;

      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token != null && token.isNotEmpty) {
        _driveAccessToken = token;
      }
    } catch (error) {
      debugPrint('[GoogleAccount] Drive permission/token refresh failed: ${error.runtimeType}');
      return null;
    }
    return _driveAccessToken;
  }

  Future<void> backupToDrive() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive permission is required for backup.');
    final data = await BackupService.instance.buildBackupData();
    await BackupService.instance.backup(data, token);
  }

  Future<int> restoreFromDrive() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive permission is required for restore.');
    final data = await BackupService.instance.restore(token);
    if (data == null) return 0;
    return BackupService.instance.restoreFromData(data);
  }

  Future<void> deleteDriveBackup() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive permission is required to delete the backup.');
    await BackupService.instance.deleteBackup(token);
  }

  Future<void> signOut() async {
    _driveAccessToken = null;
    _account = null;
    try {
      await _google.signOut();
    } catch (error) {
      debugPrint('[GoogleAccount] sign-out failed: ${error.runtimeType}');
    }
  }
}
