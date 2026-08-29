import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Downloads a verified-enough APK payload from the canonical Cloudflare
/// release endpoint and hands it to Android's package installer.
///
/// The downloaded file deliberately remains in the app cache after the install
/// intent is launched. Android's installer may read the granted URI after
/// [OpenFilex.open] returns; deleting the file immediately can make installs
/// flaky on some devices. The cache directory is OS-managed and a subsequent
/// download of the same version replaces any stale file first.
class ApkDownloader {
  ApkDownloader._();
  static final ApkDownloader instance = ApkDownloader._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

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
          'Permission needed. Go to Settings → Apps → OTYA → '
          'Install unknown apps and allow it.',
        );
        return;
      }

      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') {
        onError?.call('OTYA could not verify the update download address.');
        return;
      }

      final dir = await getTemporaryDirectory();
      final safeVersion = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final savePath = '${dir.path}/otya-$safeVersion.apk';
      final file = File(savePath);

      // A previous cancelled or superseded update must never be treated as a
      // complete package. Each fresh update starts from an empty cache file.
      if (await file.exists()) await file.delete();

      _cancelToken = CancelToken();

      await _dio.download(
        uri.toString(),
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
        options: Options(
          headers: const {
            'Accept':
                'application/vnd.android.package-archive, application/octet-stream, */*',
          },
          responseType: ResponseType.bytes,
        ),
      );

      _cancelToken = null;

      // Reject empty/error-body downloads before handing anything to Android.
      if (!await file.exists() || await file.length() < 1024) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        onError?.call('Download incomplete. Please try again.');
        return;
      }

      final fileLen = await file.length();
      debugPrint('[ApkDownloader] Cached installer $fileLen bytes');

      final result = await OpenFilex.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        onError?.call(
          'Could not open the Android installer (${result.message}). '
          'Check the Install unknown apps permission and try again.',
        );
      }
    } on DioException catch (e) {
      _cancelToken = null;
      if (!CancelToken.isCancel(e)) {
        debugPrint('[ApkDownloader] DioException: ${e.type}');
        final msg = e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout
            ? 'Download timed out. Check your internet connection and try again.'
            : 'Download failed. Check your internet and try again.';
        onError?.call(msg);
      }
    } catch (e) {
      _cancelToken = null;
      debugPrint('[ApkDownloader] Unexpected: ${e.runtimeType}');
      onError?.call('Something went wrong. Please try again.');
    }
  }

  void cancel() {
    _cancelToken?.cancel('User cancelled.');
    _cancelToken = null;
  }

  Future<bool> _requestInstallPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }
}
