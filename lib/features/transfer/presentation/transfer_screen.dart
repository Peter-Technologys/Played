import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
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
      setState(() => _error = 'Could not start local sharing. Check Wi-Fi or hotspot and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _receive(String rawUrl) async {
    if (_receiving) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'http' || !_isPrivateHost(uri.host)) {
      setState(() {
        _error = 'OTYA Transfer only accepts a nearby device on your local Wi-Fi or hotspot.';
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
            _progress = total > 0
                ? (downloaded / total).clamp(0.0, 1.0)
                : 0;
          });
        },
      );

      MediaRepository.instance.invalidate();
      await ref.read(mediaLibraryProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _receivedPath = file.path;
        _progress = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'The transfer did not finish. Keep both devices on the same local network and try again.');
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
    final library = ref.watch(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTYA Transfer'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: _ModeSwitch(
                mode: _mode,
                onChanged: _switchMode,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
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
            'Keep this screen open. The other device must be on the same Wi-Fi or hotspot.',
            style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selected!.formattedSize,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          const SizedBox(height: 8),
          const Text(
            'A computer on the same network can open this link in a browser.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('send-picker'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          'Send from your library',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a video or song. OTYA shares it directly over your local network.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_error != null) _ErrorCard(message: _error!),
        if (library.isEmpty)
          const _EmptyTransfer(
            icon: Icons.perm_media_outlined,
            title: 'No media found',
            subtitle: 'Add media to your device, then refresh Video or Music.',
          )
        else
          ...library.map(
            (item) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.isVideo ? Icons.movie_outlined : Icons.music_note_rounded,
                  size: 21,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                item.formattedSize,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: _sending && _selected?.id == item.id
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios_rounded, size: 15),
              onTap: _sending ? null : () => _send(item),
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
        subtitle: '${_receivedPath!.split('/').last}\nOTYA scanned it into your library when supported.',
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
          const SizedBox(height: 70),
          const Icon(Icons.downloading_rounded, size: 64, color: AppColors.accent),
          const SizedBox(height: 22),
          const Text('Receiving…', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          LinearProgressIndicator(value: _progress > 0 ? _progress : null, minHeight: 7),
          const SizedBox(height: 10),
          Text(
            _progress > 0 ? '${(_progress * 100).toStringAsFixed(0)}%' : 'Connecting…',
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
          'Receive nearby',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scan the QR code shown by the sending OTYA device.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorCard(message: _error!),
          const SizedBox(height: 12),
        ],
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
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
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_rounded, size: 17, color: AppColors.textSecondary),
            SizedBox(width: 7),
            Text('Local network only', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
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
  const _ModeButton({required this.label, required this.icon, required this.active, required this.onTap});

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
                Icon(icon, size: 18, color: active ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 7),
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.textSecondary)),
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
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, height: 1.4))),
          ],
        ),
      );
}

class _EmptyTransfer extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyTransfer({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 50, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
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
  const _ResultView({super.key, required this.icon, required this.title, required this.subtitle, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: AppColors.accentGreen),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ),
        ),
      );
}
