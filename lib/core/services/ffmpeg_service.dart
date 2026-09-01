import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Local media processing used by OTYA Converter and contextual video tools.
///
/// These operations use OTYA's isolated Android media-tools plugin and do not
/// require an account, AI, Cloudflare, or an upload of the user's media file.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  static const _channel = MethodChannel('com.otyaplayer.app/media_tools_v2');

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Extracts an existing audio track from a local video without re-encoding.
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    _lastErrorMessage = null;
    try {
      onProgress?.call(0.1);
      final result = await _channel.invokeMethod<String>(
        'extractAudio',
        {'path': videoPath},
      );
      onProgress?.call(1.0);
      return result;
    } on PlatformException catch (error) {
      _lastErrorMessage = _messageFor(error, operation: 'extract audio');
      debugPrint('[OTYA Converter] ${error.code}: ${error.message}');
      return null;
    } catch (error) {
      _lastErrorMessage = 'OTYA could not extract audio from this file.';
      debugPrint('[OTYA Converter] extract audio failed: ${error.runtimeType}');
      return null;
    }
  }

  /// Trims a local video to the requested time range without uploading it.
  Future<String?> trimVideo({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) async {
    _lastErrorMessage = null;
    try {
      onProgress?.call(0.1);
      final result = await _channel.invokeMethod<String>(
        'trimVideo',
        {
          'path': videoPath,
          'startMs': (startSec * 1000).toInt(),
          'endMs': (endSec * 1000).toInt(),
        },
      );
      onProgress?.call(1.0);
      return result;
    } on PlatformException catch (error) {
      _lastErrorMessage = _messageFor(error, operation: 'create this clip');
      debugPrint('[OTYA Tools] ${error.code}: ${error.message}');
      return null;
    } catch (error) {
      _lastErrorMessage = 'OTYA could not create this clip from the selected file.';
      debugPrint('[OTYA Tools] trim video failed: ${error.runtimeType}');
      return null;
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  String _messageFor(PlatformException error, {required String operation}) {
    final message = error.message?.trim();
    switch (error.code) {
      case 'TRIM_FILE_UNREADABLE':
      case 'EXTRACT_FILE_UNREADABLE':
        return message?.isNotEmpty == true
            ? message!
            : 'OTYA cannot read this local file. Check its storage permission and try again.';
      case 'TRIM_UNSUPPORTED_FORMAT':
      case 'EXTRACT_UNSUPPORTED_FORMAT':
        return message?.isNotEmpty == true
            ? message!
            : 'This codec cannot be processed locally without re-encoding.';
      case 'TRIM_SAMPLE_TOO_LARGE':
      case 'EXTRACT_SAMPLE_TOO_LARGE':
        return message?.isNotEmpty == true
            ? message!
            : 'This file uses unusually large media samples that the local tool cannot safely process.';
      case 'TRIM_NO_VIDEO':
      case 'TRIM_EMPTY_RANGE':
      case 'EXTRACT_NO_AUDIO':
      case 'EXTRACT_EMPTY':
      case 'TRIM_RANGE_INVALID':
        return message?.isNotEmpty == true ? message! : 'The selected media does not contain usable content for this operation.';
      case 'MEDIA_SAVE_FAILED':
      case 'MEDIA_OUTPUT_EMPTY':
        return message?.isNotEmpty == true
            ? message!
            : 'OTYA processed the media but Android could not save the result.';
      case 'CANCELLED':
        return 'Operation cancelled.';
      case 'BUSY':
        return 'Another media tool is already running.';
      default:
        return message?.isNotEmpty == true
            ? message!
            : 'OTYA could not $operation on this Android device.';
    }
  }

  /// Compatibility name used by older UI code.
  Future<String?> trimForWhatsApp({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) =>
      trimVideo(
        videoPath: videoPath,
        startSec: startSec,
        endSec: endSec,
        onProgress: onProgress,
      );
}
