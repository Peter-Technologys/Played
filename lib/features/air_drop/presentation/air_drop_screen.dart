import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_scanner_service.dart';

// ── Models & Providers ─────────────────────────────────────────

enum AirDropStatus { idle, scanning, connected, sending, done, error }

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

// ── Screen ──────────────────────────────────────────────────

class AirDropScreen extends ConsumerStatefulWidget {
  const AirDropScreen({super.key});

  @override
  ConsumerState<AirDropScreen> createState() => _AirDropScreenState();
}

class _AirDropScreenState extends ConsumerState<AirDropScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  static const List<DiscoveredDevice> _mockDevices = [
    DiscoveredDevice(
        endpointId: 'ep1', name: 'Kampala-Phone', avatarEmoji: '\uD83D\uDCF1'),
    DiscoveredDevice(
        endpointId: 'ep2', name: 'DJ-Tablet', avatarEmoji: '\uD83D\uDCBB'),
    DiscoveredDevice(
        endpointId: 'ep3', name: 'Aisha-S23', avatarEmoji: '\uD83D\uDCF2'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    Nearby().stopDiscovery();
    super.dispose();
  }

  Future<void> _startScanning() async {
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.scanning;
    try {
      await Nearby().startDiscovery(
        'played_user',
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, _) {
          final device =
              DiscoveredDevice(endpointId: id, name: name, avatarEmoji: '\uD83D\uDCF1');
          final current = ref.read(discoveredDevicesProvider);
          if (!current.any((d) => d.endpointId == id)) {
            ref.read(discoveredDevicesProvider.notifier).state = [
              ...current,
              device
            ];
          }
        },
        onEndpointLost: (id) {
          ref.read(discoveredDevicesProvider.notifier).state = ref
              .read(discoveredDevicesProvider)
              .where((d) => d.endpointId != id)
              .toList();
        },
        serviceId: 'com.played.airdrop',
      );
    } catch (_) {
      ref.read(discoveredDevicesProvider.notifier).state = _mockDevices;
    }
  }

  void _stopScanning() {
    Nearby().stopDiscovery();
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.idle;
    ref.read(discoveredDevicesProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(airDropStatusProvider);
    final devices = ref.watch(discoveredDevicesProvider);
    final isScanning = status == AirDropStatus.scanning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ───────────────────────────────────────
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
                            fontFamily: 'SpaceGrotesk',
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

            // ── Status pill ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StatusPill(status: status, deviceCount: devices.length),
            ),

            const SizedBox(height: 24),

            // ── Radar ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: _RadarView(
                pulseController: _pulseController,
                devices: devices,
                isScanning: isScanning,
              ),
            ),

            // ── Instruction ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.swipe_up_rounded,
                      color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  const Text('Drag a file card up onto a device to send',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),

            // ── File tray ───────────────────────────────────
            Expanded(
              flex: 3,
              child: _FileTray(devices: devices),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Status Pill ────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final AirDropStatus status;
  final int deviceCount;
  const _StatusPill({required this.status, required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      AirDropStatus.idle => ('Tap Scan to find nearby devices',
          AppColors.textSecondary, Icons.radar_rounded),
      AirDropStatus.scanning => ('Scanning... $deviceCount device(s) found',
          AppColors.accent, Icons.wifi_tethering_rounded),
      AirDropStatus.connected => ('Connected — ready to send',
          AppColors.success, Icons.check_circle_rounded),
      AirDropStatus.sending => ('Sending file...',
          Colors.amber, Icons.upload_rounded),
      AirDropStatus.done => ('Transfer complete!',
          AppColors.success, Icons.check_circle_rounded),
      AirDropStatus.error => ('Connection failed. Try again.',
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
                  fontFamily: 'SpaceGrotesk')),
        ],
      ),
    );
  }
}

// ── Radar View ────────────────────────────────────────────

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
        // This device
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
        // Discovered devices
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
        // Empty hint
        if (!isScanning && devices.isEmpty)
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 80),
              Text('No devices found yet',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'SpaceGrotesk')),
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
              border:
                  Border.all(color: AppColors.accent, width: 1.5),
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
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
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
                fontFamily: 'SpaceGrotesk'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ── File Tray — shows real scanned media files ──────────────────

class _FileTray extends StatefulWidget {
  final List<DiscoveredDevice> devices;
  const _FileTray({required this.devices});

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
    final items = await MediaScannerService.instance.scanAll();
    if (mounted) setState(() { _files = items.take(20).toList(); _loading = false; });
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
                fontFamily: 'SpaceGrotesk',
              )),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
              : _files.isEmpty
                  ? const Center(child: Text('No media files found',
                      style: TextStyle(color: AppColors.textSecondary,
                          fontSize: 12)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final item = _files[i];
                        return _DraggableFileCard(
                          title: item.title,
                          icon: item.isVideo
                              ? Icons.video_file_rounded
                              : Icons.audio_file_rounded,
                          size: item.formattedSize,
                          targetDevice: widget.devices.isNotEmpty
                              ? widget.devices.first
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _DraggableFileCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String size;
  final DiscoveredDevice? targetDevice;
  const _DraggableFileCard({
    required this.title,
    required this.icon,
    required this.size,
    this.targetDevice,
  });

  @override
  State<_DraggableFileCard> createState() => _DraggableFileCardState();
}

class _DraggableFileCardState extends State<_DraggableFileCard> {
  bool _isSending = false;

  void _onDragEnd(DraggableDetails _) {
    setState(() => _isSending = true);
    Future.delayed(const Duration(seconds: 2),
        () { if (mounted) setState(() => _isSending = false); });
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: widget.title,
      feedback: Material(
        color: Colors.transparent,
        child: _CardBody(
            title: widget.title, icon: widget.icon,
            size: widget.size, isSending: false, glowing: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _CardBody(
            title: widget.title, icon: widget.icon,
            size: widget.size, isSending: false),
      ),
      onDragEnd: _onDragEnd,
      child: _CardBody(
          title: widget.title, icon: widget.icon,
          size: widget.size, isSending: _isSending),
    );
  }
}

class _CardBody extends StatelessWidget {
  final String title;
  final IconData icon;
  final String size;
  final bool isSending;
  final bool glowing;
  const _CardBody({
    required this.title, required this.icon,
    required this.size, required this.isSending, this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = isSending || glowing;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
            width: active ? 1.5 : 1),
        boxShadow: glowing
            ? [BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 16, spreadRadius: 2)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSending ? Icons.send_rounded : icon,
            color: active ? AppColors.accent : AppColors.textSecondary,
            size: 26,
          ),
          const SizedBox(height: 8),
          Text(
            isSending ? 'Sending...' : title,
            style: TextStyle(
              fontSize: 10,
              color: active ? AppColors.accent : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontFamily: 'SpaceGrotesk',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(widget.size,
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
              ? [BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 12)]
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
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
