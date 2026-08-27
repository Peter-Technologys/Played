import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';
import 'backup_service.dart';

/// Google identity + private Drive App Folder integration.
///
/// OTYA never stores the Google OAuth access token on disk. The token is kept
/// in memory only and is refreshed by Google Sign-In when needed. OTYA account
/// tokens remain in Android Keystore via [AuthService].
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
      _driveAppDataScope,
    ],
    serverClientId: _clientId.isEmpty ? null : _clientId,
  );

  GoogleSignInAccount? _account;
  String? _driveAccessToken;

  bool get isConfigured => _clientId.isNotEmpty;
  String? get email => _account?.email;
  bool get hasGoogleSession => _account != null;

  /// Signs in to Google, authenticates the same identity with OTYA Auth, and
  /// keeps a Drive access token in memory for private appDataFolder backups.
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
      final accessToken = auth.accessToken;
      if (idToken == null || idToken.isEmpty) {
        return const AuthResult(ok: false, error: 'Google did not return an ID token.');
      }
      if (accessToken == null || accessToken.isEmpty) {
        return const AuthResult(ok: false, error: 'Google Drive permission was not granted.');
      }

      final result = await AuthService.instance.loginWithGoogle(idToken, accessToken);
      if (result.ok) {
        _account = account;
        _driveAccessToken = accessToken;
      }
      return result;
    } catch (e) {
      debugPrint('[GoogleAccount] sign-in failed: $e');
      return AuthResult(ok: false, error: 'Google Sign-In failed: $e');
    }
  }

  /// Restores an existing Google session without showing UI when possible.
  Future<bool> restoreSession() async {
    if (!isConfigured) return false;
    try {
      final account = await _google.signInSilently();
      if (account == null) return false;
      final auth = await account.authentication;
      if (auth.accessToken == null || auth.accessToken!.isEmpty) return false;
      _account = account;
      _driveAccessToken = auth.accessToken;
      return true;
    } catch (e) {
      debugPrint('[GoogleAccount] silent restore failed: $e');
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
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token != null && token.isNotEmpty) {
        _driveAccessToken = token;
      }
    } catch (e) {
      debugPrint('[GoogleAccount] token refresh failed: $e');
    }
    return _driveAccessToken;
  }

  Future<void> backupToDrive() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive is not connected.');
    final data = await BackupService.instance.buildBackupData();
    await BackupService.instance.backup(data, token);
  }

  Future<bool> restoreFromDrive() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive is not connected.');
    final data = await BackupService.instance.restore(token);
    if (data == null) return false;
    await BackupService.instance.restoreFromData(data);
    return true;
  }

  Future<void> deleteDriveBackup() async {
    final token = await _freshDriveToken();
    if (token == null) throw StateError('Google Drive is not connected.');
    await BackupService.instance.deleteBackup(token);
  }

  Future<void> signOut() async {
    _driveAccessToken = null;
    _account = null;
    try {
      await _google.signOut();
    } catch (e) {
      debugPrint('[GoogleAccount] sign-out failed: $e');
    }
  }
}
