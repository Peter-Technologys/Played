import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/data/media_repository.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum AirDropRole { sender, receiver }
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

class TransferRecord {
  final String fileName;
  final String size;
  final bool sent; // true = sent by me, false = received
  final DateTime time;
  const TransferRecord({
    required this.fileName,
    required this.size,
    required this.sent,
    required this.time,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final airDropRoleProvider    = StateProvider<AirDropRole>((_) => AirDropRole.sender);
final airDropStatusProvider  = StateProvider<AirDropStatus>((_) => AirDropStatus.idle);
final discoveredDevicesProvider = StateProvider<List<DiscoveredDevice>>((_) => []);
final sendProgressProvider   = StateProvider<double>((_) => 0.0);
final receiveProgressProvider = StateProvider<double>((_) => 0.0);
final transferHistoryProvider = StateProvider<List<TransferRecord>>((_) => []);
final selectedFilesProvider  = StateProvider<List<MediaItem>>((_) => []);
final receivedFileNameProvider = StateProvider<String?>((_) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AirDropScreen extends ConsumerStatefulWidget {
  const AirDropScreen({super.key});

  @override
  ConsumerState<AirDropScreen> createState() => _AirDropScreenState();
}

class _AirDropScreenState extends ConsumerState<AirDropScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late TabController _tabController;

  static const String _serviceId = 'com.played.airdrop';
  static const String _userName  = 'played_user';

  final Map<String, String> _connectedEndpoints = {};
  final Map<int, String> _incomingPayloadNames  = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      final role = _tabController.index == 0
          ? AirDropRole.sender
          : AirDropRole.receiver;
      ref.read(airDropRoleProvider.notifier).state = role;
      // Auto-start the right mode when tab switches
      if (role == AirDropRole.receiver) {
        _startAdvertising();
      } else {
        Nearby().stopAdvertising();
        ref.read(airDropStatusProvider.notifier).state = AirDropStatus.idle;
      }
    });
    // Start advertising immediately on open (receive-ready by default)
    _startAdvertising();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tabController.dispose();
    Nearby().stopDiscovery();
    Nearby().stopAdvertising();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  // ── Advertising (Receive mode) ──────────────────────────────────────────

  Future<void> _startAdvertising() async {
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.advertising;
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
      debugPrint('[AirDrop] Advertising error: $e');
    }
  }

  // ── Discovery (Send mode) ───────────────────────────────────────────────

  Future<void> _startScanning() async {
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.scanning;
    ref.read(discoveredDevicesProvider.notifier).state = [];
    try {
      await Nearby().startDiscovery(
        _userName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, _) {
          final device = DiscoveredDevice(
              endpointId: id,
              name: name,
              avatarEmoji: _emojiFor(name));
          final current = ref.read(discoveredDevicesProvider);
          if (!current.any((d) => d.endpointId == id)) {
            ref.read(discoveredDevicesProvider.notifier).state = [
              ...current, device];
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
      debugPrint('[AirDrop] Discovery error: $e');
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
    }
  }

  void _stopScanning() {
    Nearby().stopDiscovery();
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.idle;
    ref.read(discoveredDevicesProvider.notifier).state = [];
  }

  // ── Connection callbacks ────────────────────────────────────────────────

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    // Auto-accept all connections
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
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    if (_connectedEndpoints.isEmpty) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.idle;
    }
  }

  // ── Payload callbacks ───────────────────────────────────────────────────

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.FILE) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.receiving;
      // Store payload ID → filename mapping if available
      if (payload.filePath != null) {
        _incomingPayloadNames[payload.id] = payload.filePath!.split('/').last;
      }
    }
  }

  void _onPayloadTransferUpdate(
      String endpointId, PayloadTransferUpdate update) {
    final total = update.totalBytes;
    final done  = update.bytesTransferred;
    final progress = total > 0 ? done / total : 0.0;

    final status = ref.read(airDropStatusProvider);
    if (status == AirDropStatus.sending) {
      ref.read(sendProgressProvider.notifier).state = progress;
    } else {
      ref.read(receiveProgressProvider.notifier).state = progress;
    }

    if (update.status == PayloadStatus.SUCCESS) {
      _onTransferComplete(update, status);
    } else if (update.status == PayloadStatus.FAILURE) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
    }
  }

  Future<void> _onTransferComplete(
      PayloadTransferUpdate update, AirDropStatus prevStatus) async {
    ref.read(sendProgressProvider.notifier).state  = 0;
    ref.read(receiveProgressProvider.notifier).state = 0;
    ref.read(airDropStatusProvider.notifier).state = AirDropStatus.done;

    if (prevStatus == AirDropStatus.receiving) {
      // Move received file to Downloads/AirDrop
      final fileName = _incomingPayloadNames[update.id] ??
          'received_${DateTime.now().millisecondsSinceEpoch}';
      final dest = await _saveToDownloads(update.id, fileName);
      ref.read(receivedFileNameProvider.notifier).state = dest;

      // Add to history
      final history = ref.read(transferHistoryProvider);
      ref.read(transferHistoryProvider.notifier).state = [
        TransferRecord(
          fileName: fileName,
          size: '',
          sent: false,
          time: DateTime.now(),
        ),
        ...history,
      ];
    }

    // Reset to connected after 3 s
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.connected;
    }
  }

  Future<String?> _saveToDownloads(int payloadId, String fileName) async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download/AirDrop');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      // nearby_connections saves received files to the app cache dir
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync().whereType<File>().toList();
      for (final f in files) {
        if (f.path.contains(payloadId.toString())) {
          final dest = '${downloadsDir.path}/$fileName';
          await f.copy(dest);
          await f.delete();
          return dest;
        }
      }
    } catch (e) {
      debugPrint('[AirDrop] saveToDownloads error: $e');
    }
    return null;
  }

  // ── Send file ───────────────────────────────────────────────────────────

  Future<void> _sendFileTo(String endpointId, MediaItem item) async {
    if (!_connectedEndpoints.containsKey(endpointId)) {
      try {
        await Nearby().requestConnection(
          _userName,
          endpointId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        debugPrint('[AirDrop] requestConnection error: $e');
        ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
        return;
      }
    }
    try {
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.sending;
      ref.read(sendProgressProvider.notifier).state  = 0;
      await Nearby().sendFilePayload(endpointId, item.filePath);

      // Add to history
      final history = ref.read(transferHistoryProvider);
      ref.read(transferHistoryProvider.notifier).state = [
        TransferRecord(
          fileName: item.title,
          size: item.formattedSize,
          sent: true,
          time: DateTime.now(),
        ),
        ...history,
      ];
    } catch (e) {
      debugPrint('[AirDrop] sendFile error: $e');
      ref.read(airDropStatusProvider.notifier).state = AirDropStatus.error;
    }
  }

  Future<void> _sendSelectedFiles(String endpointId) async {
    final files = ref.read(selectedFilesProvider);
    for (final f in files) {
      await _sendFileTo(endpointId, f);
    }
    ref.read(selectedFilesProvider.notifier).state = [];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _emojiFor(String name) {
    const emojis = ['📱', '💻', '📲', '🎵', '🎧', '📡', '📳', '🖥'];
    return emojis[name.hashCode.abs() % emojis.length];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status       = ref.watch(airDropStatusProvider);
    final devices      = ref.watch(discoveredDevicesProvider);
    final sendProg     = ref.watch(sendProgressProvider);
    final recvProg     = ref.watch(receiveProgressProvider);
    final history      = ref.watch(transferHistoryProvider);
    final selected     = ref.watch(selectedFilesProvider);
    final receivedName = ref.watch(receivedFileNameProvider);
    final isScanning   = status == AirDropStatus.scanning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            _Header(
              status: status,
              isScanning: isScanning,
              onScan: isScanning ? _stopScanning : _startScanning,
            ),

            // ── Send / Receive tab bar ───────────────────────────────────
            _RoleTabBar(controller: _tabController),

            const SizedBox(height: 12),

            // ── Transfer progress ────────────────────────────────────────
            if (status == AirDropStatus.sending && sendProg > 0)
              _ProgressBar(
                  label: 'Sending', progress: sendProg,
                  color: AppColors.accent),
            if (status == AirDropStatus.receiving && recvProg > 0)
              _ProgressBar(
                  label: 'Receiving', progress: recvProg,
                  color: AppColors.accentGreen),

            // ── Done / received banner ───────────────────────────────────
            if (status == AirDropStatus.done)
              _DoneBanner(receivedName: receivedName),

            // ── Error banner ─────────────────────────────────────────────
            if (status == AirDropStatus.error)
              _ErrorBanner(onRetry: _startScanning),

            // ── Tab views ────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // ── SEND TAB ──────────────────────────────────────────
                  _SendTab(
                    pulseController: _pulseController,
                    devices: devices,
                    isScanning: isScanning,
                    selected: selected,
                    status: status,
                    onScan: isScanning ? _stopScanning : _startScanning,
                    onDeviceTap: (device) {
                      if (selected.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select files below first'),
                            backgroundColor: AppColors.surface,
                          ),
                        );
                        return;
                      }
                      _sendSelectedFiles(device.endpointId);
                    },
                    onFileSelected: (item) {
                      final current = ref.read(selectedFilesProvider);
                      if (current.any((f) => f.id == item.id)) {
                        ref.read(selectedFilesProvider.notifier).state =
                            current.where((f) => f.id != item.id).toList();
                      } else {
                        ref.read(selectedFilesProvider.notifier).state = [
                          ...current, item];
                      }
                    },
                  ),

                  // ── RECEIVE TAB ───────────────────────────────────────
                  _ReceiveTab(
                    pulseController: _pulseController,
                    status: status,
                    history: history,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AirDropStatus status;
  final bool isScanning;
  final VoidCallback onScan;
  const _Header({
    required this.status,
    required this.isScanning,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AirDropStatus.idle        => ('Ready', AppColors.textSecondary),
      AirDropStatus.advertising => ('Visible to nearby devices', AppColors.accentGreen),
      AirDropStatus.scanning    => ('Scanning for devices...', AppColors.accent),
      AirDropStatus.connected   => ('Connected', AppColors.accentGreen),
      AirDropStatus.sending     => ('Sending...', AppColors.accent),
      AirDropStatus.receiving   => ('Receiving...', AppColors.accentGreen),
      AirDropStatus.done        => ('Transfer complete!', AppColors.accentGreen),
      AirDropStatus.error       => ('Connection failed', AppColors.error),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Air-Drop',
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, fontFamily: 'Inter',
                  )),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12, color: color,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Speed badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.bolt_rounded,
                    color: AppColors.accentGreen, size: 14),
                SizedBox(width: 4),
                Text('0MB data',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role Tab Bar (Send / Receive)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleTabBar extends StatelessWidget {
  final TabController controller;
  const _RoleTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentViolet]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        tabs: const [
          Tab(icon: Icon(Icons.upload_rounded, size: 16), text: 'Send'),
          Tab(icon: Icon(Icons.download_rounded, size: 16), text: 'Receive'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final String label;
  final double progress;
  final Color color;
  const _ProgressBar(
      {required this.label, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$label ${(progress * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
              Icon(label == 'Sending'
                  ? Icons.upload_rounded
                  : Icons.download_rounded,
                  color: color, size: 14),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Done Banner
// ─────────────────────────────────────────────────────────────────────────────

class _DoneBanner extends StatelessWidget {
  final String? receivedName;
  const _DoneBanner({this.receivedName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                receivedName != null
                    ? 'Saved to Downloads/AirDrop'
                    : 'File sent successfully!',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Connection failed. Make sure both devices have Bluetooth and Wi-Fi on.',
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
            GestureDetector(
              onTap: onRetry,
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEND TAB
// ─────────────────────────────────────────────────────────────────────────────

class _SendTab extends StatefulWidget {
  final AnimationController pulseController;
  final List<DiscoveredDevice> devices;
  final bool isScanning;
  final List<MediaItem> selected;
  final AirDropStatus status;
  final VoidCallback onScan;
  final void Function(DiscoveredDevice) onDeviceTap;
  final void Function(MediaItem) onFileSelected;

  const _SendTab({
    required this.pulseController,
    required this.devices,
    required this.isScanning,
    required this.selected,
    required this.status,
    required this.onScan,
    required this.onDeviceTap,
    required this.onFileSelected,
  });

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  List<MediaItem> _allFiles = [];
  bool _loading = true;
  String _filter = 'all'; // all | audio | video

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final items = MediaRepository.instance.cachedItems ??
        await MediaRepository.instance.getAllMedia();
    if (mounted) setState(() { _allFiles = items; _loading = false; });
  }

  List<MediaItem> get _filtered {
    if (_filter == 'audio') return _allFiles.where((f) => !f.isVideo).toList();
    if (_filter == 'video') return _allFiles.where((f) => f.isVideo).toList();
    return _allFiles;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Radar ──────────────────────────────────────────────────────
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isScanning) ...[
                _PulseRing(controller: widget.pulseController, delay: 0.0, radius: 60),
                _PulseRing(controller: widget.pulseController, delay: 0.33, radius: 95),
                _PulseRing(controller: widget.pulseController, delay: 0.66, radius: 130),
              ],
              // Center device (this phone)
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 20, spreadRadius: 4)
                  ],
                ),
                child: const Icon(Icons.phone_android_rounded,
                    color: Colors.black, size: 28),
              ),
              // Discovered devices around the center
              ...List.generate(widget.devices.length, (i) {
                final angle =
                    (2 * pi / widget.devices.length) * i - pi / 2;
                const r = 110.0;
                return Transform.translate(
                  offset: Offset(cos(angle) * r, sin(angle) * r),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onDeviceTap(widget.devices[i]);
                    },
                    child: _DeviceNode(device: widget.devices[i])
                        .animate()
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          delay: Duration(milliseconds: i * 100),
                          curve: Curves.elasticOut,
                        ),
                  ),
                );
              }),
              // Empty state
              if (!widget.isScanning && widget.devices.isEmpty)
                Positioned(
                  bottom: 8,
                  child: GestureDetector(
                    onTap: widget.onScan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentViolet]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 16)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar_rounded,
                              color: Colors.black, size: 18),
                          SizedBox(width: 8),
                          Text('Scan for Devices',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                fontFamily: 'Inter',
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.isScanning)
                Positioned(
                  bottom: 8,
                  child: GestureDetector(
                    onTap: widget.onScan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_rounded,
                              color: AppColors.error, size: 16),
                          SizedBox(width: 6),
                          Text('Stop Scanning',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Selected files count + send hint ───────────────────────────
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.selected.length} file${widget.selected.length == 1 ? '' : 's'} selected — tap a device to send',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

        // ── File type filter ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Text('FILES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  )),
              const Spacer(),
              _FilterChip(
                  label: 'All',
                  active: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 6),
              _FilterChip(
                  label: '🎵 Audio',
                  active: _filter == 'audio',
                  onTap: () => setState(() => _filter = 'audio')),
              const SizedBox(width: 6),
              _FilterChip(
                  label: '🎥 Video',
                  active: _filter == 'video',
                  onTap: () => setState(() => _filter = 'video')),
            ],
          ),
        ),

        // ── File grid ─────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2))
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('No files found',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final item = _filtered[i];
                        final isSelected = widget.selected
                            .any((f) => f.id == item.id);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onFileSelected(item);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.12)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        item.isVideo
                                            ? Icons.video_file_rounded
                                            : Icons.audio_file_rounded,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppColors.accent
                                              : AppColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.formattedSize,
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 6, right: 6,
                                    child: Container(
                                      width: 18, height: 18,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.black,
                                          size: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECEIVE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiveTab extends StatelessWidget {
  final AnimationController pulseController;
  final AirDropStatus status;
  final List<TransferRecord> history;
  const _ReceiveTab({
    required this.pulseController,
    required this.status,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == AirDropStatus.advertising ||
        status == AirDropStatus.connected ||
        status == AirDropStatus.receiving;

    return Column(
      children: [
        // ── Receive radar ──────────────────────────────────────────────
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive) ...[
                _PulseRing(
                    controller: pulseController, delay: 0.0, radius: 60),
                _PulseRing(
                    controller: pulseController, delay: 0.33, radius: 95),
                _PulseRing(
                    controller: pulseController, delay: 0.66, radius: 130),
              ],
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                      color: isActive
                          ? AppColors.accentGreen
                          : AppColors.border,
                      width: 2),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: AppColors.accentGreen
                                  .withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 4)
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: isActive
                      ? AppColors.accentGreen
                      : AppColors.textSecondary,
                  size: 36,
                ),
              ),
              Positioned(
                bottom: 8,
                child: Text(
                  isActive
                      ? 'Waiting for files from nearby devices...'
                      : 'Switch to this tab to receive files',
                  style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? AppColors.accentGreen
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // ── Transfer history ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              const Text('TRANSFER HISTORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  )),
              const Spacer(),
              if (history.isNotEmpty)
                Text('${history.length} transfer${history.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),

        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded,
                          color: AppColors.textSecondary, size: 40),
                      const SizedBox(height: 12),
                      const Text('No transfers yet',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                          'Files you send or receive will appear here',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final record = history[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: (record.sent
                                      ? AppColors.accent
                                      : AppColors.accentGreen)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              record.sent
                                  ? Icons.upload_rounded
                                  : Icons.download_rounded,
                              color: record.sent
                                  ? AppColors.accent
                                  : AppColors.accentGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(record.fileName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  '${record.sent ? 'Sent' : 'Received'} · ${_timeAgo(record.time)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle_rounded,
                            color: record.sent
                                ? AppColors.accent
                                : AppColors.accentGreen,
                            size: 18,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 40));
                  },
                ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceNode extends StatelessWidget {
  final DiscoveredDevice device;
  const _DeviceNode({required this.device});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  blurRadius: 12)
            ],
          ),
          child: Center(
              child: Text(device.avatarEmoji,
                  style: const TextStyle(fontSize: 26))),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(device.name,
              style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
      {required this.controller, required this.delay, required this.radius});

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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.accent : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.accent : AppColors.textSecondary,
            )),
      ),
    );
  }
}
