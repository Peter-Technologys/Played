/// Canonical network boundary for OTYA Transfer and its internal Together proxy.
///
/// OTYA deliberately uses cleartext HTTP only on a nearby private IPv4 network
/// or on this device's IPv4 loopback. Keep all URI/host acceptance rules here
/// so presentation, peer discovery, playback and the downloader cannot drift.
final RegExp _transferTokenPattern = RegExp(r'^[a-f0-9]{64}$');

bool isPrivateTransferIpv4Host(
  String host, {
  bool allowLoopback = true,
}) {
  final parts = host.split('.');
  if (parts.length != 4) return false;

  final octets = parts.map(int.tryParse).toList(growable: false);
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }

  final a = octets[0]!;
  final b = octets[1]!;
  if (allowLoopback && a == 127) return true;

  return a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168);
}

bool isLoopbackTransferIpv4Host(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList(growable: false);
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }
  return octets[0] == 127;
}

bool isAllowedTransferUri(Uri uri) {
  final normalTransfer = uri.path == '/media';
  final internalTogetherProxy =
      uri.path == '/together-stream' && isLoopbackTransferIpv4Host(uri.host);

  if (uri.scheme != 'http' ||
      (!normalTransfer && !internalTogetherProxy) ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.port <= 0 ||
      uri.port > 65535 ||
      !isPrivateTransferIpv4Host(uri.host)) {
    return false;
  }

  final tokenValues = uri.queryParametersAll['t'];
  if (tokenValues == null || tokenValues.length != 1) return false;
  return _transferTokenPattern.hasMatch(tokenValues.single);
}
