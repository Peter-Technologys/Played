import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/data/media_repository.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

enum AirDropRole { idle, advertising, discovering }

class AirDropState {
  final AirDropRole role;
  final Map<String, String> discoveredEndpoints; // endpointId → name
  final Map<String, String> connectedEndpoints;  // endpointId → name
  final List<String> log;
  final bool isTransferring;
  final double transferProgress;
  final String? lastReceivedPath;

  const AirDropState({
    this.role = AirDropRole.idle,
    this.discoveredEndpoints = const {},
    this.connectedEndpoints = const {},
    this.log = const [],
    this.isTransferring = false,
    this.transferProgress = 0,
    this.lastReceivedPath,
  });

  AirDropState copyWith({
    AirDropRole? role,
    Map<String, String>? discoveredEndpoints,
    Map<String, String>? connectedEndpoints,
    List<String>? log,
    bool? isTransferring,
    double? transferProgress,
    String? lastReceivedPath,
  }) => AirDropState(
    role: role ?? this.role,
    discoveredEndpoints: discoveredEndpoints ?? this.discoveredEndpoints,
    connectedEndpoints: connectedEndpoints ?? this.connectedEndpoints,
    log: log ?? this.log,
    isTransferring: isTransferring ?? this.isTransferring,
    transferProgress: transferProgress ?? this.transferProgress,
    lastReceivedPath: lastReceivedPath ?? this.lastReceivedPath,
  );
}

class AirDropNotifier extends StateNotifier<AirDropState> {
  static const _serviceId = 'com.petersmart.played.airdrop';
  static const _strategy  = Strategy.P2P_CLUSTER;

  String _myName = 'PLAYED Device';

  AirDropNotifier() : super(const AirDropState()) {
    _myName = 'PLAYED-${DateTime.now().millisecondsSinceEpoch % 9999}';
  }

  void _log(String msg) {
    state = state.copyWith(log: [msg, ...state.log.take(19)]);
  }

  // ── Advertise (receive mode) ───────────────────────────────────────────────

  Future<void> startAdvertising() async {
    await _stopAll();
    state = state.copyWith(role: AirDropRole.advertising);
    _log('Waiting for nearby devices...');
    try {
      await Nearby().startAdvertising(
        _myName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
    } catch (e) {
      _log('Advertise error: $e');
      state = state.copyWith(role: AirDropRole.idle);
    }
  }

  // ── Discover (send mode) ─────────────────────────────────────────────────

  Future<void> startDiscovering() async {
    await _stopAll();
    state = state.copyWith(
      role: AirDropRole.discovering,
      discoveredEndpoints: {},
    );
    _log('Scanning for nearby devices...');
    try {
      await Nearby().startDiscovery(
        _myName,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          if (!mounted) return;
          final updated = Map<String, String>.from(state.discoveredEndpoints)
            ..[id] = name;
          state = state.copyWith(discoveredEndpoints: updated);
          _log('Found: $name');
        },
        onEndpointLost: (id) {
          if (!mounted) return;
          final updated = Map<String, String>.from(state.discoveredEndpoints)
            ..remove(id);
          state = state.copyWith(discoveredEndpoints: updated);
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      _log('Discover error: $e');
      state = state.copyWith(role: AirDropRole.idle);
    }
  }

  // ── Connect & send ────────────────────────────────────────────────────────

  Future<void> connectAndSend(String endpointId, MediaItem file) async {
    _log('Connecting to ${state.discoveredEndpoints[endpointId]}...');
    try {
      await Nearby().requestConnection(
        _myName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) async {
          _onConnectionResult(id, status);
          if (status == Status.CONNECTED) {
            await _sendFile(id, file);
          }
        },
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _log('Connect error: $e');
    }
  }

  Future<void> _sendFile(String endpointId, MediaItem file) async {
    state = state.copyWith(isTransferring: true, transferProgress: 0);
    _log('Sending ${file.title}...');
    try {
      await Nearby().sendFilePayload(endpointId, file.filePath);
      _log('Sent ${file.title} ✔');
    } catch (e) {
      _log('Send error: $e');
    } finally {
      if (mounted) state = state.copyWith(isTransferring: false);
    }
  }

  // ── Connection callbacks ──────────────────────────────────────────────────

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    _log('Connection from ${info.endpointName} — accepting...');
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (!mounted) return;
    if (status == Status.CONNECTED) {
      final name = state.discoveredEndpoints[id] ?? id;
      final connected = Map<String, String>.from(state.connectedEndpoints)
        ..[id] = name;
      state = state.copyWith(connectedEndpoints: connected);
      _log('Connected to $name');
    } else {
      _log('Connection failed: $status');
    }
  }

  void _onDisconnected(String id) {
    if (!mounted) return;
    final connected = Map<String, String>.from(state.connectedEndpoints)
      ..remove(id);
    state = state.copyWith(connectedEndpoints: connected);
    _log('Disconnected: $id');
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.FILE) {
      _log('Receiving file...');
      state = state.copyWith(isTransferring: true, transferProgress: 0);
      // File is saved to the app’s cache dir by nearby_connections
      // Move it to Downloads after transfer completes
    }
  }

  void _onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) async {
    if (!mounted) return;
    final progress = update.bytesTransferred / (update.totalBytes == 0 ? 1 : update.totalBytes);
    state = state.copyWith(transferProgress: progress);

    if (update.status == PayloadStatus.SUCCESS) {
      _log('Transfer complete ✔');
      state = state.copyWith(isTransferring: false, transferProgress: 1.0);
      // Move received file to Downloads and trigger media scan
      await _moveReceivedFile(update.id);
    } else if (update.status == PayloadStatus.FAILURE) {
      _log('Transfer failed ✘');
      state = state.copyWith(isTransferring: false);
    }
  }

  Future<void> _moveReceivedFile(int payloadId) async {
    try {
      // nearby_connections saves files to cache dir with payload ID as name
      final cacheDir = await getTemporaryDirectory();
      final received = File('${cacheDir.path}/$payloadId');
      if (!await received.exists()) return;

      final downloadsDir = Directory('/storage/emulated/0/Download/PLAYED');
      await downloadsDir.create(recursive: true);
      final dest = File('${downloadsDir.path}/${received.path.split('/').last}');
      await received.copy(dest.path);
      await received.delete();

      state = state.copyWith(lastReceivedPath: dest.path);
      _log('Saved to ${dest.path}');

      // Trigger MediaStore scan so the file appears in My Space immediately
      MediaRepository.instance.invalidate();
    } catch (e) {
      _log('Save error: $e');
    }
  }

  Future<void> stop() => _stopAll();

  Future<void> _stopAll() async {
    try { await Nearby().stopAdvertising(); } catch (_) {}
    try { await Nearby().stopDiscovery(); } catch (_) {}
    try { await Nearby().stopAllEndpoints(); } catch (_) {}
    if (mounted) state = state.copyWith(role: AirDropRole.idle);
  }

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }
}

final airDropProvider =
    StateNotifierProvider<AirDropNotifier, AirDropState>(
  (_) => AirDropNotifier(),
);

// ── Screen ───────────────────────────────────────────────────────────────────────────

class AirDropScreen extends ConsumerStatefulWidget {
  const AirDropScreen({super.key});

  @override
  ConsumerState<AirDropScreen> createState() => _AirDropScreenState();
}

class _AirDropScreenState extends ConsumerState<AirDropScreen> {
  @override
  void initState() {
    super.initState();
    _ensurePermissions();
  }

  Future<void> _ensurePermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final s   = ref.watch(airDropProvider);
    final lib = ref.watch(mediaLibraryProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Air-Drop',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            )),
        centerTitle: true,
        actions: [
          if (s.role != AirDropRole.idle)
            TextButton(
              onPressed: () => ref.read(airDropProvider.notifier).stop(),
              child: const Text('Stop',
                  style: TextStyle(color: AppColors.error, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Mode buttons ─────────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _ModeBtn(
                    icon: Icons.download_rounded,
                    label: 'Receive',
                    subtitle: 'Wait for files',
                    active: s.role == AirDropRole.advertising,
                    onTap: s.role == AirDropRole.idle
                        ? () => ref.read(airDropProvider.notifier).startAdvertising()
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeBtn(
                    icon: Icons.upload_rounded,
                    label: 'Send',
                    subtitle: 'Find nearby devices',
                    active: s.role == AirDropRole.discovering,
                    onTap: s.role == AirDropRole.idle
                        ? () => ref.read(airDropProvider.notifier).startDiscovering()
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // ── Transfer progress ─────────────────────────────────────────────────────────────
          if (s.isTransferring)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transferring...',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: s.transferProgress,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

          // ── Discovered devices (send mode) ─────────────────────────────────────────────
          if (s.role == AirDropRole.discovering &&
              s.discoveredEndpoints.isNotEmpty) ...
            [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('NEARBY DEVICES',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary, letterSpacing: 1.2,
                      )),
                ),
              ),
              ...s.discoveredEndpoints.entries.map((e) => _DeviceTile(
                    name: e.value,
                    onSend: () => _pickAndSend(context, ref, e.key, lib),
                  )),
            ],

          // ── Activity log ─────────────────────────────────────────────────────────────────────
          if (s.log.isNotEmpty) ...
            [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ACTIVITY',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary, letterSpacing: 1.2,
                      )),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: s.log.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      s.log[i],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ]
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_tethering_rounded,
                          color: AppColors.accent, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('100% Offline — No Internet Needed',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 6),
                    const Text(
                      'Uses Wi-Fi Direct + Bluetooth.\nTap Receive on one device, Send on the other.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pickAndSend(
      BuildContext context, WidgetRef ref, String endpointId,
      List<MediaItem> library) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Pick a file to send',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: library.length,
                itemBuilder: (_, i) {
                  final item = library[i];
                  return ListTile(
                    leading: Icon(
                      item.isVideo
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                      color: AppColors.accent,
                    ),
                    title: Text(item.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.formattedSize,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      ref
                          .read(airDropProvider.notifier)
                          .connectAndSend(endpointId, item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────────────────

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;
  const _ModeBtn({
    required this.icon, required this.label,
    required this.subtitle, required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet])
              : null,
          color: active ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? Colors.transparent : AppColors.border),
          boxShadow: active
              ? [BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? Colors.black : AppColors.accent, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: active ? Colors.black : AppColors.textPrimary,
                )),
            Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? Colors.black.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final String name;
  final VoidCallback onSend;
  const _DeviceTile({required this.name, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.phone_android_rounded,
            color: AppColors.accent, size: 20),
      ),
      title: Text(name,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14)),
      subtitle: const Text('Tap to send a file',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      trailing: ElevatedButton(
        onPressed: onSend,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        child: const Text('Send',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}
