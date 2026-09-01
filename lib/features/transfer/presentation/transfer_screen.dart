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
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../air_drop/data/media_receiver.dart';
import '../../air_drop/data/media_sender.dart';
import '../../my_space/data/media_repository.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';

enum _TransferMode { send, receive }

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final MediaSender _sender = MediaSender();
  final MediaReceiver _receiver = MediaReceiver();
  final MobileScannerController _scanner = MobileScannerController();

  _TransferMode _mode = _TransferMode.send;
  MediaItem? _selected;
  String? _shareUrl;
  String? _receivedPath;
  String? _error;
  double _progress = 0;
  bool _sending = false;
  bool _receiving = false;
  bool _scanLocked = false;

  @override
  void dispose() {
    _sender.stop();
    _receiver.cancel();
    _scanner.stop();
    _scanner.dispose();
    super.dispose();
  }

  void _switchMode(_TransferMode mode) {
    HapticFeedback.selectionClick();
    if (_mode == mode) return;
    _sender.stop();
    _receiver.cancel();
    setState(() {
      _mode = mode;
      _shareUrl = null;
      _receivedPath = null;
      _error = null;
      _progress = 0;
      _sending = false;
      _receiving = false;
      _scanLocked = false;
    });
  }

  Future<void> _send(MediaItem item) async {
    if (_sending) return;
    HapticFeedback.lightImpact();
    _sender.stop();
    setState(() {
      _selected = item;
      _sending = true;
      _shareUrl = null;
      _error = null;
    });
    try {
      final url = await _sender.startServing(item.filePath);
      if (!mounted) return;
      setState(() => _shareUrl = url);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not start local sharing. Check Wi-Fi or hotspot and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _receive(String rawUrl) async {
    if (_receiving) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'http' || !_isPrivateHost(uri.host)) {
      setState(() {
        _error =
            'OTYA Transfer only accepts a nearby device on your local Wi-Fi or hotspot.';
        _scanLocked = false;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _receiving = true;
      _error = null;
      _receivedPath = null;
      _progress = 0;
    });

    try {
      final base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/OTYA_Received');
      await dir.create(recursive: true);
      final advertised = uri.queryParameters['name']
          ?.replaceAll('\\', '/')
          .split('/')
          .last
          .trim();
      final fileName = advertised != null && advertised.isNotEmpty
          ? advertised
          : 'received_${DateTime.now().millisecondsSinceEpoch}.bin';

      final file = await _receiver.download(
        url: rawUrl,
        savePath: '${dir.path}/$fileName',
        onProgress: (downloaded, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0;
          });
        },
      );

      MediaRepository.instance.invalidate();
      await MediaScannerService.instance.scanDirectory(dir.path);
      if (!mounted) return;
      setState(() {
        _receivedPath = file.path;
        _progress = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'The transfer did not finish. Keep both devices on the same local network and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _receiving = false;
          _scanLocked = false;
        });
      }
    }
  }

  bool _isPrivateHost(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((n) => n == null)) return false;
    final a = nums[0]!;
    final b = nums[1]!;
    return a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31);
  }

  @override
  Widget build(BuildContext context) {
    final library =
        ref.watch(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[];
    return WallpaperScaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
        actions: [
          if (_shareUrl != null)
            TextButton(
              onPressed: () {
                _sender.stop();
                setState(() => _shareUrl = null);
              },
              child: const Text('Stop'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _TransferIntro(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _ModeSwitch(
                mode: _mode,
                onChanged: _switchMode,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _mode == _TransferMode.send
                    ? _sendBody(context, library)
                    : _receiveBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sendBody(BuildContext context, List<MediaItem> library) {
    if (_shareUrl != null && _selected != null) {
      return ListView(
        key: const ValueKey('send-ready'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 6),
          Text(
            'Ready to send',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Keep this screen open. The receiving device must stay on the same Wi-Fi or hotspot.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 28,
                    offset: Offset(0, 10),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: QrImageView(
                data: _shareUrl!,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _selected!.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selected!.formattedSize,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _shareUrl!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transfer link copied')),
              );
            },
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('Copy link for phone or computer'),
          ),
          const SizedBox(height: 10),
          const _LocalOnlyNote(),
        ],
      );
    }

    return ListView(
      key: const ValueKey('send-picker'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          'Choose what to send',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select a local video or song. OTYA creates a temporary link only for devices on your nearby network.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorCard(message: _error!),
          const SizedBox(height: 12),
        ],
        if (library.isEmpty)
          const _EmptyTransfer(
            icon: Icons.perm_media_outlined,
            title: 'No media found',
            subtitle: 'Add media to this device, then refresh Video or Music.',
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < library.length; index++) ...[
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        library[index].isVideo
                            ? Icons.movie_outlined
                            : Icons.music_note_rounded,
                        size: 21,
                        color: AppColors.accent,
                      ),
                    ),
                    title: Text(
                      library[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      library[index].formattedSize,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: _sending && _selected?.id == library[index].id
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _sending ? null : () => _send(library[index]),
                  ),
                  if (index != library.length - 1)
                    Divider(
                      height: 1,
                      indent: 72,
                      color: AppColors.borderOf(context),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _receiveBody(BuildContext context) {
    if (_receivedPath != null) {
      return _ResultView(
        key: const ValueKey('receive-done'),
        icon: Icons.check_circle_rounded,
        title: 'File received',
        subtitle:
            '${_receivedPath!.split('/').last}\nOTYA scanned it into your library when supported.',
        action: 'Receive another',
        onAction: () => setState(() {
          _receivedPath = null;
          _error = null;
          _progress = 0;
          _scanLocked = false;
        }),
      );
    }

    if (_receiving) {
      return ListView(
        key: const ValueKey('receiving'),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Container(
            width: 78,
            height: 78,
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.downloading_rounded,
              size: 38,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Receiving…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep both devices on the same nearby network until the transfer finishes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 10),
          Text(
            _progress > 0
                ? '${(_progress * 100).toStringAsFixed(0)}%'
                : 'Connecting…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () {
              _receiver.cancel();
              setState(() {
                _receiving = false;
                _progress = 0;
                _scanLocked = false;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('receive-scan'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      children: [
        Text(
          'Scan to receive',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scan the QR code from the sending OTYA device. Only private local-network addresses are accepted.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorCard(message: _error!),
          const SizedBox(height: 12),
        ],
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: .45),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: SizedBox(
                width: 280,
                height: 280,
                child: MobileScanner(
                  controller: _scanner,
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    if (_scanLocked || capture.barcodes.isEmpty) return;
                    final value = capture.barcodes.first.rawValue ??
                        capture.barcodes.first.displayValue;
                    if (value == null || !value.startsWith('http://')) return;
                    _scanLocked = true;
                    _receive(value);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _LocalOnlyNote(),
      ],
    );
  }
}

class _TransferIntro extends StatelessWidget {
  const _TransferIntro();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrustIcon(),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby. Direct. No upload.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Transfer sends files between devices on the same Wi-Fi or hotspot. OTYA does not route the file through its cloud.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TrustIcon extends StatelessWidget {
  const _TrustIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.wifi_tethering_rounded,
          color: AppColors.accentGreen,
          size: 21,
        ),
      );
}

class _LocalOnlyNote extends StatelessWidget {
  const _LocalOnlyNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentGreen.withValues(alpha: .16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 17,
              color: AppColors.accentGreen,
            ),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'Local network only · no OTYA cloud upload',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ModeSwitch extends StatelessWidget {
  final _TransferMode mode;
  final ValueChanged<_TransferMode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            _ModeButton(
              label: 'Send',
              icon: Icons.north_east_rounded,
              active: mode == _TransferMode.send,
              onTap: () => onChanged(_TransferMode.send),
            ),
            _ModeButton(
              label: 'Receive',
              icon: Icons.south_west_rounded,
              active: mode == _TransferMode.receive,
              onTap: () => onChanged(_TransferMode.receive),
            ),
          ],
        ),
      );
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: .22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _EmptyTransfer extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyTransfer({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Icon(icon, size: 32, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
}

class _ResultView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;
  const _ResultView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 68, color: AppColors.accentGreen),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onAction, child: Text(action)),
              ],
            ),
          ),
        ),
      );
}
