import 'dart:async';

import '../../transfer/data/media_sender.dart';
import '../../transfer/data/transfer_security_policy.dart';
import '../data/media_fingerprint_service.dart';
import '../data/nearby_together_channel.dart';
import '../domain/media_identity.dart';

enum NearbyPlaybackSourceKind {
  /// Both phones already own the same media. Only sync/chat traffic is sent.
  localCopy,

  /// Guest does not have the same complete file and plays the host's LAN Range
  /// source directly. This still requires no internet or cloud upload.
  hostLanStream,
}

class NearbyPlaybackPlan {
  final NearbyPlaybackSourceKind kind;
  final OtyaMediaIdentity remoteMedia;
  final String? localFilePath;
  final Uri? hostMediaUrl;
  final String hostDisplayName;
  final String? hostUsername;

  const NearbyPlaybackPlan._({
    required this.kind,
    required this.remoteMedia,
    required this.hostDisplayName,
    this.hostUsername,
    this.localFilePath,
    this.hostMediaUrl,
  });

  const NearbyPlaybackPlan.local({
    required OtyaMediaIdentity remoteMedia,
    required String localFilePath,
    required String hostDisplayName,
    String? hostUsername,
  }) : this._(
          kind: NearbyPlaybackSourceKind.localCopy,
          remoteMedia: remoteMedia,
          localFilePath: localFilePath,
          hostDisplayName: hostDisplayName,
          hostUsername: hostUsername,
        );

  const NearbyPlaybackPlan.stream({
    required OtyaMediaIdentity remoteMedia,
    required Uri hostMediaUrl,
    required String hostDisplayName,
    String? hostUsername,
  }) : this._(
          kind: NearbyPlaybackSourceKind.hostLanStream,
          remoteMedia: remoteMedia,
          hostMediaUrl: hostMediaUrl,
          hostDisplayName: hostDisplayName,
          hostUsername: hostUsername,
        );
}

class NearbyTogetherHostSession {
  final MediaSender _mediaSender;
  final NearbyTogetherHost channel;

  OtyaMediaIdentity? _mediaIdentity;
  Uri? _mediaUrl;

  NearbyTogetherHostSession({
    MediaSender? mediaSender,
    NearbyTogetherHost? channel,
  })  : _mediaSender = mediaSender ?? MediaSender(),
        channel = channel ?? NearbyTogetherHost();

  OtyaMediaIdentity? get mediaIdentity => _mediaIdentity;
  Uri? get mediaUrl => _mediaUrl;

  Future<NearbyTogetherInvite> start({
    required String filePath,
    required String displayName,
    String? username,
    Duration? duration,
    String? mimeType,
  }) async {
    await stop();

    final media = await MediaFingerprintService.instance.identify(
      filePath: filePath,
      duration: duration,
      mimeType: mimeType,
    );
    final url = Uri.parse(await _mediaSender.startServing(filePath));
    if (!isAllowedTransferUri(url)) {
      await _mediaSender.stop();
      throw StateError('OTYA produced an invalid nearby media source.');
    }

    try {
      final invite = await channel.start(
        displayName: displayName,
        username: username,
        media: media,
        hostMediaUrl: url,
      );
      _mediaIdentity = media;
      _mediaUrl = url;
      return invite;
    } catch (_) {
      await _mediaSender.stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _mediaIdentity = null;
    _mediaUrl = null;
    await channel.stop();
    await _mediaSender.stop();
  }

  Future<void> dispose() async {
    await stop();
    await channel.dispose();
  }
}

class NearbyTogetherGuestSession {
  final NearbyTogetherGuest channel;

  NearbyTogetherGuestSession({NearbyTogetherGuest? channel})
      : channel = channel ?? NearbyTogetherGuest();

  Future<NearbyPlaybackPlan> join({
    required Uri inviteUri,
    String? candidateLocalFilePath,
    Duration? candidateDuration,
    String? candidateMimeType,
  }) async {
    // Subscribe before opening the socket so the host's immediate hello cannot
    // race past a broadcast listener on fast local networks.
    final helloFuture = channel.messages
        .firstWhere((message) => message.type == 'hello')
        .timeout(const Duration(seconds: 10));

    await channel.connect(inviteUri);

    NearbyTogetherMessage hello;
    try {
      hello = await helloFuture;
    } catch (_) {
      await channel.disconnect();
      rethrow;
    }

    final plan = await _planFromHello(
      hello,
      candidateLocalFilePath: candidateLocalFilePath,
      candidateDuration: candidateDuration,
      candidateMimeType: candidateMimeType,
    );

    await channel.send('ready', {
      'source': plan.kind.name,
      'has_complete_media': plan.kind == NearbyPlaybackSourceKind.localCopy,
    });
    return plan;
  }

  Future<NearbyPlaybackPlan> _planFromHello(
    NearbyTogetherMessage hello, {
    required String? candidateLocalFilePath,
    required Duration? candidateDuration,
    required String? candidateMimeType,
  }) async {
    final payload = hello.payload;
    final mediaJson = payload['media'];
    if (mediaJson is! Map) {
      throw const FormatException('Nearby Together host did not provide media identity.');
    }

    final media = Map<String, dynamic>.from(mediaJson);
    final fingerprint = media['fingerprint'];
    final byteLength = media['byte_length'];
    if (fingerprint is! String || fingerprint.isEmpty || byteLength is! int || byteLength <= 0) {
      throw const FormatException('Nearby Together media identity is invalid.');
    }

    final remote = OtyaMediaIdentity(
      fingerprint: fingerprint,
      byteLength: byteLength,
      duration: media['duration_ms'] is int
          ? Duration(milliseconds: media['duration_ms'] as int)
          : null,
      mimeType: media['mime_type'] is String ? media['mime_type'] as String : null,
    );

    final displayName = payload['display_name'] is String
        ? (payload['display_name'] as String).trim()
        : 'OTYA user';
    final username = payload['username'] is String
        ? (payload['username'] as String).trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase()
        : null;

    if (candidateLocalFilePath != null && candidateLocalFilePath.trim().isNotEmpty) {
      try {
        final local = await MediaFingerprintService.instance.identify(
          filePath: candidateLocalFilePath,
          duration: candidateDuration,
          mimeType: candidateMimeType,
        );
        if (local.sameMediaAs(remote)) {
          return NearbyPlaybackPlan.local(
            remoteMedia: remote,
            localFilePath: candidateLocalFilePath,
            hostDisplayName: displayName,
            hostUsername: username,
          );
        }
      } catch (_) {
        // A missing/unreadable candidate is not fatal: fall back to the host's
        // authenticated LAN stream rather than failing the Together session.
      }
    }

    final rawUrl = payload['media_url'];
    final hostUrl = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (hostUrl == null || !isAllowedTransferUri(hostUrl)) {
      throw const FormatException('Nearby Together host media source is invalid.');
    }

    // The media URL must resolve to the same host device as the control socket,
    // preventing a valid Together peer from redirecting playback to the public
    // internet or another LAN machine.
    // inviteUri host checking occurs at channel connect; the URL itself is still
    // restricted to RFC1918 by isAllowedTransferUri.
    return NearbyPlaybackPlan.stream(
      remoteMedia: remote,
      hostMediaUrl: hostUrl,
      hostDisplayName: displayName,
      hostUsername: username,
    );
  }

  Future<void> leave() => channel.disconnect();

  Future<void> dispose() => channel.dispose();
}
