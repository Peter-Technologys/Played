import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';
import 'backup_service.dart';

/// Google identity + private Drive App Folder integration.
///
/// Basic Google Sign-In requests identity only. The narrower Drive App Data
/// permission is requested lazily when the user explicitly backs up, restores,
/// or deletes a backup. OTYA never stores the Google OAuth access token on disk.
/// OTYA account tokens remain in Android Keystore via [AuthService].
class GoogleAccountService {
  GoogleAccountService._();
  static final GoogleAccountService instance = GoogleAccountService._();

  static const String _clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static const String _driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  late final GoogleSignIn _google = GoogleSignIn(
    scopes: const <String>[
      'email',
      'profile',
    ],
    serverClientId: _clientId.isEmpty ? null : _clientId,
  );

  GoogleSignInAccount? _account;
  String? _driveAccessToken;

  bool get isConfigured => _clientId.isNotEmpty;
  String? get email => _account?.email;
  bool get hasGoogleSession => _account != null;

  /// Authenticates the Google identity with OTYA Auth.
  ///
  /// Drive permission is intentionally NOT requested here and no Drive access
  /// token is sent to /auth/google. This keeps normal account sign-in separate
  /// from optional cloud recovery consent.
  Future<AuthResult> signInAndAuthenticate() async {
    if (!isConfigured) {
      return const AuthResult(
        ok: false,
        error: 'Google Sign-In is not configured for this build yet.',
      );
    }

    try {
      final account = await _google.signIn();
      if (account == null) {
        return const AuthResult(ok: false, error: 'Google Sign-In was cancelled.');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const AuthResult(ok: false, error: 'Google did not return an ID token.');
      }

      // Keep the existing AuthService contract compatible while deliberately
      // sending no Drive credential during basic authentication.
      final result = await AuthService.instance.loginWithGoogle(idToken, '');
      if (result.ok) {
        _account = account;
        _driveAccessToken = null;
      }
      return result;
    } catch (e) {
      debugPrint('[GoogleAccount] sign-in failed: ${e.runtimeType}');
      return const AuthResult(
        ok: false,
        error: 'Google Sign-In could not be completed. Please try again.',
      );
    }
  }

  /// Restores an existing identity session without asking for Drive permission.
  Future<bool> restoreSession() async {
    if (!isConfigured) return false;
    try {
      final account = await _google.signInSilently();
      if (account == null) return false;
      _account = account;
      _driveAccessToken = null;
      return true;
    } catch (e) {
      debugPrint('[GoogleAccount] silent restore failed: ${e.runtimeType}');
      return false;
    }
  }

  /// Requests only the private app-data Drive scope when cloud recovery is
  /// actually used. The resulting access token remains memory-only.
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
    } catch (e) {
      debugPrint('[GoogleAccount] Drive permission/token refresh failed: ${e.runtimeType}');
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

  Future<bool> restoreFromDrive() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive permission is required for restore.');
    final data = await BackupService.instance.restore(token);
    if (data == null) return false;
    await BackupService.instance.restoreFromData(data);
    return true;
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
    } catch (e) {
      debugPrint('[GoogleAccount] sign-out failed: ${e.runtimeType}');
    }
  }
}
