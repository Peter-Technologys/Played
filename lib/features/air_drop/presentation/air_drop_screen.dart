import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../../../app/theme/app_colors.dart';

// ── Models & Providers ─────────────────────────────────────────

enum AirDropStatus { idle, scanning, sending, done, error }

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

// ── Screen ────────────────────────────────────────────────────

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
        endpointId: 'ep1',
        name: 'Kampala-Phone',
        avatarEmoji: '\uD83D\uDCF1'),
    DiscoveredDevice(
        endpointId: 'ep2', name: 'DJ-Tablet', avatarEmoji: '\uD83D\uDCBB'),
    DiscoveredDevice(
        endpointId: 'ep3', name: 'Aisha-S23', avatarEmoji: '\uD83D\uDCF2'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    ref.read(airDropStatusProvider.notifier).state =
        AirDropStatus.scanning;
    try {
      await Nearby().startDiscovery(
        'played_user',
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, serviceId) {
          final device = DiscoveredDevice(
              endpointId: id, name: name, avatarEmoji: '\uD83D\uDCF1');
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
      // Fallback to mock devices for demo
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
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Air-Drop',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                      const Text(
                        '0MB data \u00b7 Wi-Fi Direct + Bluetooth',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
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
            const SizedBox(height: 32),
            // Radar
            Expanded(
              flex: 3,
              child: _RadarView(
                pulseController: _pulseController,
                devices: devices,
                isScanning: isScanning,
              ),
            ),
            // File tray
            Expanded(
              flex: 2,
              child: _FileTray(devices: devices),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Radar View ───────────────────────────────────────────────

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
        if (isScanning) ..._pulseRings(),
        // Center phone icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.phone_android_rounded,
              color: AppColors.accent, size: 28),
        ),
        // Device avatars in a circle
        ...List.generate(devices.length, (i) {
          final angle =
              (2 * pi / devices.length) * i - pi / 2;
          const radius = 130.0;
          return Transform.translate(
            offset: Offset(
                cos(angle) * radius, sin(angle) * radius),
            child: _DeviceAvatar(device: devices[i])
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  delay: Duration(milliseconds: i * 120),
                  curve: Curves.elasticOut,
                ),
          );
        }),
      ],
    );
  }

  List<Widget> _pulseRings() => [
        _PulseRing(controller: pulseController, delay: 0.0, radius: 80),
        _PulseRing(controller: pulseController, delay: 0.3, radius: 120),
        _PulseRing(controller: pulseController, delay: 0.6, radius: 160),
      ];
}

class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double radius;

  const _PulseRing({
    required this.controller,
    required this.delay,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final progress = ((controller.value + delay) % 1.0);
        return Opacity(
          opacity: (1.0 - progress).clamp(0.0, 0.4),
          child: Container(
            width: radius * 2 * progress + radius,
            height: radius * 2 * progress + radius,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.accent, width: 1.5),
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Center(
            child: Text(device.avatarEmoji,
                style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          device.name,
          style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontFamily: 'SpaceGrotesk'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── File Tray ─────────────────────────────────────────────────

class _FileTray extends StatelessWidget {
  final List<DiscoveredDevice> devices;
  const _FileTray({required this.devices});

  static const List<Map<String, dynamic>> _mockFiles = [
    {'title': 'Omwana_Remix.mp3', 'icon': Icons.audio_file_rounded},
    {'title': 'Kampala_Night.mp4', 'icon': Icons.video_file_rounded},
    {'title': 'DJ_Ciza_Mix.mp3', 'icon': Icons.audio_file_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Drag a file up to share',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'SpaceGrotesk'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _mockFiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _DraggableFileCard(
              title: _mockFiles[i]['title'] as String,
              icon: _mockFiles[i]['icon'] as IconData,
              targetDevice:
                  devices.isNotEmpty ? devices.first : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Draggable File Card ───────────────────────────────────────

class _DraggableFileCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final DiscoveredDevice? targetDevice;

  const _DraggableFileCard({
    required this.title,
    required this.icon,
    this.targetDevice,
  });

  @override
  State<_DraggableFileCard> createState() =>
      _DraggableFileCardState();
}

class _DraggableFileCardState extends State<_DraggableFileCard> {
  bool _isSending = false;

  void _onDragEnd(DraggableDetails _) {
    setState(() => _isSending = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isSending = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: widget.title,
      feedback: _CardBody(
          title: widget.title,
          icon: widget.icon,
          isSending: false,
          scale: 1.1,
          glowing: true),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _CardBody(
            title: widget.title,
            icon: widget.icon,
            isSending: false),
      ),
      onDragEnd: _onDragEnd,
      child: _CardBody(
          title: widget.title,
          icon: widget.icon,
          isSending: _isSending),
    );
  }
}

class _CardBody extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSending;
  final double scale;
  final bool glowing;

  const _CardBody({
    required this.title,
    required this.icon,
    required this.isSending,
    this.scale = 1.0,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSending || glowing
                ? AppColors.accent
                : AppColors.border,
            width: isSending || glowing ? 1.5 : 1,
          ),
          boxShadow: glowing
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSending ? Icons.send_rounded : icon,
              color: isSending
                  ? AppColors.accent
                  : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              isSending ? 'Sending...' : title,
              style: TextStyle(
                fontSize: 10,
                color: isSending
                    ? AppColors.accent
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: 'SpaceGrotesk',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan Button ────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isScanning ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isScanning ? AppColors.accent : AppColors.border,
          ),
          boxShadow: isScanning
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.35),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Text(
          isScanning ? 'Stop' : 'Scan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isScanning ? Colors.black : AppColors.textPrimary,
            fontFamily: 'SpaceGrotesk',
          ),
        ),
      ),
    );
  }
}
