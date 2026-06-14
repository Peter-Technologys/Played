import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/data/media_repository.dart';
import 'dart:math';

// ── Models & Providers ───────────────────────────────────────────────

enum AirDropStatus { idle, advertising, scanning, connected, sending, receiving, done, error }

class DiscoveredDevice {
  final String endpointId;
  final String name;
  final String avatarEmoji;
  const DiscoveredDevice({
    required this.endpointId,
    required this.name,
    required this.avatarEmoji,
  });
}

final airDropStatusProvider =
    StateProvider<AirDropStatus>((_) => AirDropStatus.idle);
final discoveredDevicesProvider =
    StateProvider<List<DiscoveredDevice>>((_) => []);
final sendProgressProvider = StateProvider<double>((_) => 0.0);
final receiveProgressProvider = StateProvider<double>((_) => 0.0);
final receivedFileProvider = StateProvider<String?>((_) => null);

// ── Screen ──────────────────────────────────────────────────────

class AirDropScreen extends ConsumerStatefulWidget {
  const AirDropScreen({super.key});

  @override
  ConsumerState<AirDropScreen> createState() => _AirDropScreenState();
}

class _AirDropScreenState extends ConsumerState<AirDropScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final Map<String, String> _connectedEndpoints = {}; // endpointId -> name

  static const String _serviceId = 'com.played.airdrop';
  static const String _userName  = 'played_user';

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    // Start advertising immediately so other devices can find this one
    _startAdvertising();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    Nearby().stopDiscovery();
    Nearby().stopAdvertising();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  // ── Advertising (receive mode) ──────────────────────────────────

  Future<void> _startAdvertising() async {
    try {
      await Nearby().startAdvertising(
        _userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
    } catch (e) {
      debugPrint('[AirDrop] Advertising failed: $e');
    }
  }

  // ── Discovery (send mode) ───────────────────────────────────────

  Future<void> _startScanning() async {
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.scanning;
    try {
      await Nearby().startDiscovery(
        _userName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, _) {
          final device = DiscoveredDevice(
              endpointId: id,
              name: name,
              avatarEmoji: _emojiForName(name));
          final current = ref.read(discoveredDevicesProvider);
          if (!current.any((d) => d.endpointId == id)) {
            ref.read(discoveredDevicesProvider.notifier).state = [
              ...current,
              device,
            ];
          }
        },
        onEndpointLost: (id) {
          ref.read(discoveredDevicesProvider.notifier).state = ref
              .read(discoveredDevicesProvider)
              .where((d) => d.endpointId != id)
              .toList();
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      debugPrint('[AirDrop] Discovery failed: $e');
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
    }
  }

  void _stopScanning() {
    Nearby().stopDiscovery();
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.idle;
    ref.read(discoveredDevicesProvider.notifier).state = [];
  }

  // ── Connection callbacks ────────────────────────────────────────

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    // Auto-accept all incoming connections
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
    _connectedEndpoints[endpointId] = info.endpointName;
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.connected;
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints[endpointId] = endpointId;
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.connected;
    } else {
      _connectedEndpoints.remove(endpointId);
      if (_connectedEndpoints.isEmpty) {
        ref.read(airDropStatusProvider.notifier).state = AirDropStatus.scanning;
      }
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    if (_connectedEndpoints.isEmpty) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.idle;
    }
  }

  // ── Payload callbacks ───────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.FILE) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.receiving;
      // The file is saved automatically by the nearby_connections plugin
      // to the app's cache directory. We track it via transfer updates.
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    final total = update.totalBytes;
    final transferred = update.bytesTransferred;
    if (total > 0) {
      final progress = transferred / total;
      final status = ref.read(airDropStatusProvider);
      if (status == AirDropStatus.sending) {
        ref.read(sendProgressProvider.notifier).state = progress;
      } else {
        ref.read(receiveProgressProvider.notifier).state = progress;
      }
    }
    if (update.status == PayloadStatus.SUCCESS) {
      final currentStatus = ref.read(airDropStatusProvider);
      if (currentStatus == AirDropStatus.receiving) {
        // File received — copy to Downloads
        _saveReceivedFile(update.id);
      }
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.done;
      ref.read(sendProgressProvider.notifier).state = 0;
      ref.read(receiveProgressProvider.notifier).state = 0;
    } else if (update.status == PayloadStatus.FAILURE) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
    }
  }

  Future<void> _saveReceivedFile(int payloadId) async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download/AirDrop');
      if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      // nearby_connections saves received files to cache — move to Downloads
      final cacheDir = Directory('/data/data/com.petersmart.played/cache');
      final files = cacheDir.listSync().whereType<File>().toList();
      for (final f in files) {
        if (f.path.contains(payloadId.toString())) {
          final dest = '${downloadsDir.path}/${f.path.split('/').last}';
          await f.copy(dest);
          await f.delete();
          ref.read(receivedFileProvider.notifier).state = dest;
          break;
        }
      }
    } catch (e) {
      debugPrint('[AirDrop] saveReceivedFile error: $e');
    }
  }

  // ── Send file to endpoint ───────────────────────────────────────

  Future<void> _sendFile(String endpointId, MediaItem item) async {
    if (!_connectedEndpoints.containsKey(endpointId)) {
      // Request connection first
      try {
        await Nearby().requestConnection(
          _userName,
          endpointId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
      } catch (e) {
        debugPrint('[AirDrop] requestConnection error: $e');
        ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
        return;
      }
      // Wait briefly for connection to establish
      await Future.delayed(const Duration(milliseconds: 800));
    }

    try {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.sending;
      ref.read(sendProgressProvider.notifier).state = 0;
      await Nearby().sendFilePayload(endpointId, item.filePath);
    } catch (e) {
      debugPrint('[AirDrop] sendFile error: $e');
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
    }
  }

  String _emojiForName(String name) {
    const emojis = ['📱', '💻', '📲', '🎵', '🎧', '📡'];
    return emojis[name.hashCode.abs() % emojis.length];
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(airDropStatusProvider);
    final devices = ref.watch(discoveredDevicesProvider);
    final isScanning = status == AirDropStatus.scanning;
    final sendProgress = ref.watch(sendProgressProvider);
    final receiveProgress = ref.watch(receiveProgressProvider);
    final receivedFile = ref.watch(receivedFileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Air-Drop',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          )),
                      const SizedBox(height: 2),
                      const Text('0MB data · Wi-Fi Direct + Bluetooth',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  _ScanButton(
                    isScanning: isScanning,
                    onTap: isScanning ? _stopScanning : _startScanning,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Status pill ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StatusPill(status: status, deviceCount: devices.length),
            ),

            // ── Transfer progress bars ────────────────────────────────
            if (status == AirDropStatus.sending && sendProgress > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sending... ${(sendProgress * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.accent)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sendProgress,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

            if (status == AirDropStatus.receiving && receiveProgress > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receiving... ${(receiveProgress * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.accentGreen)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: receiveProgress,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accentGreen),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

            if (status == AirDropStatus.done && receivedFile != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saved to Downloads/AirDrop',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Radar ──────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: _RadarView(
                pulseController: _pulseController,
                devices: devices,
                isScanning: isScanning,
              ),
            ),

            // ── Instruction ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded,
                      color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  const Text('Tap a file card to send to a discovered device',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),

            // ── File tray ───────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _FileTray(
                devices: devices,
                onSend: _sendFile,
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Status Pill ────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final AirDropStatus status;
  final int deviceCount;
  const _StatusPill({required this.status, required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      AirDropStatus.idle       => ('Advertising — tap Scan to find devices',
          AppColors.textSecondary, Icons.radar_rounded),
      AirDropStatus.advertising => ('Visible to nearby devices',
          AppColors.accentGreen, Icons.wifi_tethering_rounded),
      AirDropStatus.scanning   => ('Scanning... $deviceCount device(s) found',
          AppColors.accent, Icons.wifi_tethering_rounded),
      AirDropStatus.connected  => ('Connected — tap a file to send',
          AppColors.accentGreen, Icons.check_circle_rounded),
      AirDropStatus.sending    => ('Sending file...',
          Colors.amber, Icons.upload_rounded),
      AirDropStatus.receiving  => ('Receiving file...',
          AppColors.accentGreen, Icons.download_rounded),
      AirDropStatus.done       => ('Transfer complete!',
          AppColors.accentGreen, Icons.check_circle_rounded),
      AirDropStatus.error      => ('Connection failed. Try again.',
          AppColors.error, Icons.error_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

// ── Radar View ────────────────────────────────────────────────

class _RadarView extends StatelessWidget {
  final AnimationController pulseController;
  final List<DiscoveredDevice> devices;
  final bool isScanning;
  const _RadarView({
    required this.pulseController,
    required this.devices,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isScanning) ...[
          _PulseRing(controller: pulseController, delay: 0.0, radius: 70),
          _PulseRing(controller: pulseController, delay: 0.33, radius: 110),
          _PulseRing(controller: pulseController, delay: 0.66, radius: 150),
        ],
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4)
            ],
          ),
          child: const Icon(Icons.phone_android_rounded,
              color: AppColors.accent, size: 30),
        ),
        ...List.generate(devices.length, (i) {
          final angle = (2 * pi / devices.length) * i - pi / 2;
          const r = 130.0;
          return Transform.translate(
            offset: Offset(cos(angle) * r, sin(angle) * r),
            child: _DeviceAvatar(device: devices[i])
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  delay: Duration(milliseconds: i * 100),
                  curve: Curves.elasticOut,
                ),
          );
        }),
        if (!isScanning && devices.isEmpty)
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 80),
              Text('Tap Scan to find nearby devices',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Inter')),
            ],
          ),
      ],
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double radius;
  const _PulseRing(
      {required this.controller,
      required this.delay,
      required this.radius});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final p = ((controller.value + delay) % 1.0);
        return Opacity(
          opacity: (1.0 - p).clamp(0.0, 0.35),
          child: Container(
            width: radius * 2 * p + radius,
            height: radius * 2 * p + radius,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceAvatar extends StatelessWidget {
  final DiscoveredDevice device;
  const _DeviceAvatar({required this.device});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  blurRadius: 10)
            ],
          ),
          child: Center(
              child: Text(device.avatarEmoji,
                  style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(height: 5),
        Text(device.name,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontFamily: 'Inter'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ── File Tray ───────────────────────────────────────────────────

class _FileTray extends StatefulWidget {
  final List<DiscoveredDevice> devices;
  final Future<void> Function(String endpointId, MediaItem item) onSend;
  const _FileTray({required this.devices, required this.onSend});

  @override
  State<_FileTray> createState() => _FileTrayState();
}

class _FileTrayState extends State<_FileTray> {
  List<MediaItem> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final items = MediaRepository.instance.cachedItems ??
        await MediaRepository.instance.getAllMedia();
    if (mounted) {
      setState(() {
        _files = items.take(20).toList();
        _loading = false;
      });
    }
  }

  void _onFileTapped(BuildContext context, MediaItem item) {
    if (widget.devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices found. Tap Scan first.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    if (widget.devices.length == 1) {
      widget.onSend(widget.devices.first.endpointId, item);
      return;
    }
    // Multiple devices — show picker
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send to',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...widget.devices.map((d) => ListTile(
                  leading: Text(d.avatarEmoji,
                      style: const TextStyle(fontSize: 24)),
                  title: Text(d.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSend(d.endpointId, item);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('YOUR FILES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontFamily: 'Inter',
              )),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2))
              : _files.isEmpty
                  ? const Center(
                      child: Text('No media files found',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final item = _files[i];
                        return GestureDetector(
                          onTap: () => _onFileTapped(context, item),
                          child: _CardBody(
                            title: item.title,
                            icon: item.isVideo
                                ? Icons.video_file_rounded
                                : Icons.audio_file_rounded,
                            size: item.formattedSize,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  final String title;
  final IconData icon;
  final String size;
  const _CardBody({
    required this.title,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(size,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onTap;
  const _ScanButton({required this.isScanning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isScanning ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isScanning ? AppColors.accent : AppColors.border),
          boxShadow: isScanning
              ? [
                  BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 12)
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isScanning ? Icons.stop_rounded : Icons.radar_rounded,
              color: isScanning ? Colors.black : AppColors.textPrimary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isScanning ? 'Stop' : 'Scan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isScanning ? Colors.black : AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
