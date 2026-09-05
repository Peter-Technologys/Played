/// Canonical file-type boundary for OTYA Transfer.
///
/// Sender and receiver must use this one policy so a format can never be
/// advertised by one side and rejected by the other after the connection has
/// already started.
const Set<String> supportedTransferMediaExtensions = {
  'mp4',
  'mkv',
  'avi',
  'mov',
  'webm',
  'ts',
  'mp3',
  'aac',
  'flac',
  'wav',
  'ogg',
  'm4a',
  'opus',
};

String transferFileExtension(String path) {
  final name = path.replaceAll('\\', '/').split('/').last;
  final dot = name.lastIndexOf('.');
  return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
}

bool isSupportedTransferMediaPath(String path) =>
    supportedTransferMediaExtensions.contains(transferFileExtension(path));

String transferMimeTypeForPath(String path) {
  const map = {
    'mp4': 'video/mp4',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'ts': 'video/mp2t',
    'mp3': 'audio/mpeg',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    'opus': 'audio/opus',
    'apk': 'application/vnd.android.package-archive',
  };
  return map[transferFileExtension(path)] ?? 'application/octet-stream';
}
