/// Canonical network boundary for OTYA Transfer.
///
/// OTYA Transfer deliberately uses cleartext HTTP only on a nearby private
/// IPv4 network. Keep all URI/host acceptance rules here so presentation,
/// sender discovery and the downloader cannot drift apart.
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

bool isAllowedTransferUri(Uri uri) {
  if (uri.scheme != 'http' ||
      uri.path != '/media' ||
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
