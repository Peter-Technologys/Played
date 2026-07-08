import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Downloads an APK from the Cloudflare Worker and triggers the Android installer.
class ApkDownloader {
  ApkDownloader._();
  static final ApkDownloader instance = ApkDownloader._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10),
    followRedirects: true,
    maxRedirects: 5,
  ));

  CancelToken? _cancelToken;
  bool get isDownloading => _cancelToken != null;

  Future<void> downloadAndInstall({
    required String url,
    required String version,
    void Function(double progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      if (!await _requestInstallPermission()) {
        onError?.call(
          "Permission needed. Go to Settings → Apps → OTYA Player → "
          "Install unknown apps and allow it.",
        );
        return;
      }

      final dir      = await getTemporaryDirectory();
      final savePath = '${dir.path}/otya-player-$version.apk';
      final file     = File(savePath);

      // Always delete a stale partial download before starting.
      if (await file.exists()) await file.delete();

      _cancelToken = CancelToken();

      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
        options: Options(
          headers: {'Accept': 'application/vnd.android.package-archive'},
          responseType: ResponseType.bytes,
        ),
      );

      _cancelToken = null;

      // Verify the file was actually written and is non-empty.
      if (!await file.exists() || await file.length() < 1024) {
        onError?.call('Download incomplete. Please try again.');
        return;
      }

      final fileLen = await file.length();
      debugPrint('[ApkDownloader] Saved to $savePath ($fileLen bytes)');

      // Open installer — cancel token already cleared above so dispose() is safe.
      final result = await OpenFilex.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        onError?.call(
          'Could not open the installer (${result.message}). '
          'Try opening the file manually from your Downloads folder.',
        );
      }
    } on DioException catch (e) {
      _cancelToken = null;
      if (!CancelToken.isCancel(e)) {
        debugPrint('[ApkDownloader] DioException: $e');
        final msg = e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout
            ? 'Download timed out. Check your internet connection and try again.'
            : 'Download failed. Check your internet and try again.';
        onError?.call(msg);
      }
    } catch (e) {
      _cancelToken = null;
      debugPrint('[ApkDownloader] Unexpected: $e');
      onError?.call('Something went wrong. Please try again.');
    }
  }

  void cancel() {
    _cancelToken?.cancel('User cancelled.');
    _cancelToken = null;
  }

  Future<bool> _requestInstallPermission() async {
    if (!Platform.isAndroid) return false;
    // REQUEST_INSTALL_PACKAGES is only needed on Android 8+ (API 26+).
    // On older versions the permission is granted at install time.
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }
}
