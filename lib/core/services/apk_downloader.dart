import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Downloads an APK from the Cloudflare Worker and triggers the Android installer.
/// The Worker streams the APK from the private R2 bucket — the app never touches R2 directly.
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
          'Permission needed. Go to Settings and allow \'Install unknown apps\' for OTYA Player.',
        );
        return;
      }

      final dir      = await getTemporaryDirectory();
      final savePath = '${dir.path}/otya-player-$version.apk';
      final file     = File(savePath);
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
      debugPrint('[ApkDownloader] Saved to $savePath');

      final result = await OpenFilex.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        onError?.call('Could not open installer: ${result.message}');
      }
    } on DioException catch (e) {
      _cancelToken = null;
      if (!CancelToken.isCancel(e)) {
        debugPrint('[ApkDownloader] Error: $e');
        onError?.call('Download failed. Check your internet and try again.');
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
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    return (await Permission.requestInstallPackages.request()).isGranted;
  }
}
