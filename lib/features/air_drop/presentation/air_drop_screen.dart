import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_scanner_service.dart';
import '../../../core/widgets/modern_aura_background.dart';
import '../../../core/widgets/modern_glass_container.dart';
import '../../../core/theme/app_spacing.dart';
import '../../my_space/data/media_repository.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../data/media_sender.dart';
import '../data/media_receiver.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum _Tab { send, receive }
enum _SendStep { idle, serving }
enum _ReceiveStep { scanning, downloading, done, error }

class _AirDropState {
  final _Tab         tab;
  final _SendStep    sendStep;
  final _ReceiveStep receiveStep;
  final String?      serverUrl;
  final MediaItem?   selectedItem;
  final double       progress;
  final String?      receivedPath;
  final String?      errorMessage;
  final List<String> log;

  const _AirDropState({
    this.tab          = _Tab.send,
    this.sendStep     = _SendStep.idle,
    this.receiveStep  = _ReceiveStep.scanning,
    this.serverUrl,
    this.selectedItem,
    this.progress     = 0,
    this.receivedPath,
    this.errorMessage,
    this.log          = const [],
  });

  _AirDropState copyWith({
    _Tab?         tab,
    _SendStep?    sendStep,
    _ReceiveStep? receiveStep,
    String?       serverUrl,
    MediaItem?    selectedItem,
    double?       progress,
    String?       receivedPath,
    String?       errorMessage,
    List<String>? log,
  }) => _AirDropState(
    tab:          tab          ?? this.tab,
    sendStep:     sendStep     ?? this.sendStep,
    receiveStep:  receiveStep  ?? this.receiveStep,
    serverUrl:    serverUrl    ?? this.serverUrl,
    selectedItem: selectedItem ?? this.selectedItem,
    progress:     progress     ?? this.progress,
    receivedPath: receivedPath ?? this.receivedPath,
    errorMessage: errorMessage ?? this.errorMessage,
    log:          log          ?? this.log,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class _AirDropNotifier extends StateNotifier<_AirDropState> {
  _AirDropNotifier() : super(const _AirDropState());

  final _sender   = MediaSender();
  final _receiver = MediaReceiver();

  void _log(String msg) =>
      state = state.copyWith(log: [msg, ...state.log.take(29)]);

  void switchTab(_Tab tab) {
    stopSending();
    state = state.copyWith(
        tab: tab, sendStep: _SendStep.idle,
        receiveStep: _ReceiveStep.scanning, log: []);
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> startServing(MediaItem item) async {
    state = state.copyWith(selectedItem: item, sendStep: _SendStep.serving, serverUrl: null);
    _log('Starting server for “${item.title}”…');
    try {
      final url = await _sender.startServing(item.filePath);
      state = state.copyWith(serverUrl: url);
      _log('Ready. Show QR to receiver.');
    } catch (e) {
      _log('Error: $e');
      state = state.copyWith(sendStep: _SendStep.idle);
    }
  }

  Future<void> shareApk() async {
    state = state.copyWith(sendStep: _SendStep.serving, serverUrl: null);
    _log('Preparing APK…');
    try {
      final url = await _sender.startServingApk();
      if (url == null) { _log('APK not found.'); state = state.copyWith(sendStep: _SendStep.idle); return; }
      state = state.copyWith(serverUrl: url);
      _log('APK ready. Show QR.');
    } catch (e) { _log('APK error: $e'); state = state.copyWith(sendStep: _SendStep.idle); }
  }

  void stopSending() {
    _sender.stop();
    state = state.copyWith(sendStep: _SendStep.idle, serverUrl: null);
  }

  // ── Receive ───────────────────────────────────────────────────────────────

  Future<void> onQrScanned(String url) async {
    if (state.receiveStep == _ReceiveStep.downloading) return;
    state = state.copyWith(
        receiveStep: _ReceiveStep.downloading, progress: 0, errorMessage: null);
    _log('Connecting to $url…');
    try {
      final dir     = await getExternalStorageDirectory() ??
                      await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/OTYA_Received');
      await saveDir.create(recursive: true);
      final fileName = url.split('/').last.contains('.')
          ? url.split('/').last
          : 'received_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = await _receiver.download(
        url: url,
        savePath: '${saveDir.path}/$fileName',
        onProgress: (dl, total) {
          if (!mounted) return;
          state = state.copyWith(progress: total > 0 ? dl / total : 0.0);
        },
      );
      MediaRepository.instance.invalidate();
      await MediaScannerService.instance.scanDirectory(saveDir.path);
      state = state.copyWith(
          receiveStep: _ReceiveStep.done, receivedPath: file.path, progress: 1.0);
      _log('Saved: ${file.path} ✔');
    } catch (e) {
      _log('Error: $e');
      state = state.copyWith(receiveStep: _ReceiveStep.error, errorMessage: e.toString());
    }
  }

  void resetReceive() => state = state.copyWith(
      receiveStep: _ReceiveStep.scanning, progress: 0,
      receivedPath: null, errorMessage: null);

  void cancelDownload() { _receiver.cancel(); resetReceive(); _log('Cancelled.'); }

  @override
  void dispose() { _sender.stop(); super.dispose(); }
}

final _airDropProvider =
    StateNotifierProvider.autoDispose<_AirDropNotifier, _AirDropState>(
  (_) => _AirDropNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────

class AirDropScreen extends ConsumerStatefulWidget {
  const AirDropScreen({super.key});
  @override
  ConsumerState<AirDropScreen> createState() => _AirDropScreenState();
}

class _AirDropScreenState extends ConsumerState<AirDropScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _scanCtrl = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging)
        ref.read(_airDropProvider.notifier)
            .switchTab(_tabCtrl.index == 0 ? _Tab.send : _Tab.receive);
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); _scanCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s   = ref.watch(_airDropProvider);
    final lib = ref.watch(mediaLibraryProvider).valueOrNull ?? [];
    return ModernAuraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Flash Share',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800, fontFamily: 'Inter', fontSize: 18)),
          centerTitle: true,
          actions: [
            if (s.sendStep == _SendStep.serving)
              TextButton(
                onPressed: () => ref.read(_airDropProvider.notifier).stopSending(),
                child: const Text('Stop',
                    style: TextStyle(color: AppColors.error, fontFamily: 'Inter')),
              ),
          ],
        ),
        body: Column(
          children: [
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14)),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(12)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontFamily: 'Inter', fontSize: 13),
                tabs: const [Tab(text: '📤  Send'), Tab(text: '📥  Receive')],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SendView(state: s, library: lib),
                  _ReceiveView(state: s, scanCtrl: _scanCtrl),
                ],
              ),
            ),
            // Activity log
            if (s.log.isNotEmpty)
              Container(
                height: 80,
                margin: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: ModernGlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: s.log.length,
                    itemBuilder: (_, i) => Text(s.log[i],
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary,
                            fontFamily: 'Inter')),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Send View ─────────────────────────────────────────────────────────────────

class _SendView extends ConsumerWidget {
  final _AirDropState   state;
  final List<MediaItem> library;
  const _SendView({required this.state, required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(_airDropProvider.notifier);
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QR panel
          if (state.serverUrl != null) ...[
            ModernGlassContainer(
              child: Column(
                children: [
                  const Text('Scan on the receiving device',
                      style: TextStyle(fontSize: 13,
                          color: AppColors.textSecondary, fontFamily: 'Inter')),
                  AppSpacing.vMd,
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(
                        data: state.serverUrl!,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  AppSpacing.vSm,
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: state.serverUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied')));
                    },
                    child: Text(state.serverUrl!,
                        style: const TextStyle(fontSize: 11,
                            color: AppColors.accent, fontFamily: 'Inter',
                            decoration: TextDecoration.underline),
                        textAlign: TextAlign.center),
                  ),
                  if (state.selectedItem != null) ...[
                    AppSpacing.vSm,
                    Text('🎥 ${state.selectedItem!.title}  •  ${state.selectedItem!.formattedSize}',
                        style: const TextStyle(fontSize: 12,
                            color: AppColors.textSecondary, fontFamily: 'Inter'),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            AppSpacing.vMd,
          ],
          // Share APK
          _GlassButton(
            icon: Icons.install_mobile_rounded,
            label: 'Share OTYA Player APK',
            subtitle: 'Let friends install without internet',
            color: AppColors.accentViolet,
            onTap: () => n.shareApk(),
          ),
          AppSpacing.vSm,
          // File list
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('PICK A FILE TO SEND',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2, fontFamily: 'Inter')),
          ),
          ...library.take(50).map((item) => _FileTile(
            item: item,
            isSelected: state.selectedItem?.id == item.id,
            onTap: () => n.startServing(item),
          )),
          if (library.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('No media files found.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontFamily: 'Inter')),
              ),
            ),
          AppSpacing.vXxl,
        ],
      ),
    );
  }
}

// ── Receive View ─────────────────────────────────────────────────────────────

class _ReceiveView extends ConsumerWidget {
  final _AirDropState          state;
  final MobileScannerController scanCtrl;
  const _ReceiveView({required this.state, required this.scanCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(_airDropProvider.notifier);
    return Padding(
      padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
      child: switch (state.receiveStep) {
        _ReceiveStep.scanning    => _scanner(n),
        _ReceiveStep.downloading => _downloading(n),
        _ReceiveStep.done        => _done(n),
        _ReceiveStep.error       => _error(n),
      },
    );
  }

  Widget _scanner(_AirDropNotifier n) {
    bool scanned = false;
    return Column(
      children: [
        const Text('Point camera at the sender’s QR code',
            style: TextStyle(fontSize: 13,
                color: AppColors.textSecondary, fontFamily: 'Inter')),
        AppSpacing.vMd,
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: MobileScanner(
              controller: scanCtrl,
              onDetect: (capture) {
                if (scanned) return;
                final url = capture.barcodes.firstOrNull?.rawValue;
                if (url != null && url.startsWith('http')) {
                  scanned = true;
                  HapticFeedback.mediumImpact();
                  n.onQrScanned(url);
                }
              },
            ),
          ),
        ),
        AppSpacing.vMd,
      ],
    );
  }

  Widget _downloading(_AirDropNotifier n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.download_rounded, color: AppColors.accent, size: 56),
      AppSpacing.vMd,
      const Text('Downloading…',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter')),
      AppSpacing.vMd,
      ModernGlassContainer(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 8,
              ),
            ),
            AppSpacing.vSm,
            Text(
              state.progress > 0
                  ? '${(state.progress * 100).toStringAsFixed(1)}%'
                  : 'Connecting…',
              style: const TextStyle(color: AppColors.textSecondary,
                  fontFamily: 'Inter', fontSize: 13),
            ),
          ],
        ),
      ),
      AppSpacing.vLg,
      TextButton(
        onPressed: n.cancelDownload,
        child: const Text('Cancel',
            style: TextStyle(color: AppColors.error, fontFamily: 'Inter')),
      ),
    ],
  );

  Widget _done(_AirDropNotifier n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
            color: AppColors.accentGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded,
            color: AppColors.accentGreen, size: 44),
      ),
      AppSpacing.vMd,
      const Text('File received! ✔',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary, fontFamily: 'Inter')),
      AppSpacing.vSm,
      if (state.receivedPath != null)
        Text(state.receivedPath!.split('/').last,
            style: const TextStyle(color: AppColors.textSecondary,
                fontFamily: 'Inter', fontSize: 12),
            textAlign: TextAlign.center),
      AppSpacing.vSm,
      const Text('Added to your media library.',
          style: TextStyle(color: AppColors.accentGreen,
              fontFamily: 'Inter', fontSize: 13)),
      AppSpacing.vLg,
      ElevatedButton(
        onPressed: n.resetReceive,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent, foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.sm + 4),
        ),
        child: const Text('Receive Another',
            style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter')),
      ),
    ],
  );

  Widget _error(_AirDropNotifier n) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 56),
      AppSpacing.vMd,
      const Text('Download failed',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter')),
      AppSpacing.vSm,
      if (state.errorMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(state.errorMessage!,
              style: const TextStyle(color: AppColors.textSecondary,
                  fontFamily: 'Inter', fontSize: 12),
              textAlign: TextAlign.center),
        ),
      AppSpacing.vLg,
      ElevatedButton(
        onPressed: n.resetReceive,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Try Again',
            style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter')),
      ),
    ],
  );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon; final String label, subtitle;
  final Color color; final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.label,
      required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ModernGlassContainer(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                    fontFamily: 'Inter')),
                Text(subtitle, style: const TextStyle(fontSize: 11,
                    color: AppColors.textSecondary, fontFamily: 'Inter')),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    ),
  );
}

class _FileTile extends StatelessWidget {
  final MediaItem item; final bool isSelected; final VoidCallback onTap;
  const _FileTile({required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            size: 20,
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.accent : AppColors.textPrimary,
                        fontFamily: 'Inter'),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.formattedSize,
                    style: const TextStyle(fontSize: 11,
                        color: AppColors.textSecondary, fontFamily: 'Inter')),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.wifi_tethering_rounded,
                color: AppColors.accent, size: 18),
        ],
      ),
    ),
  );
}
