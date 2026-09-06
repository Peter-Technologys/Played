import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otya_transfer_android/otya_transfer_android.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../transfer/data/transfer_hotspot_service.dart';
import '../../transfer/presentation/transfer_screen.dart';

/// Compatibility entry for older routes/deep links.
///
/// Send remains one contextual Otya surface. The small offline-network action
/// adds the Android local-only hotspot capability without creating a separate
/// transfer app or a new main-navigation tab.
class AirDropScreen extends StatefulWidget {
  const AirDropScreen({super.key});

  @override
  State<AirDropScreen> createState() => _AirDropScreenState();
}

class _AirDropScreenState extends State<AirDropScreen> {
  final TransferHotspotService _hotspot = TransferHotspotService.instance;
  bool _startingHotspot = false;
  bool _ownsHotspot = false;

  @override
  void initState() {
    super.initState();
    // Ask only after the user explicitly enters Send. Playback, library scan,
    // startup and Together remain independent from this Android permission.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _hotspot.ensureLocalNetworkAccess();
    });
  }

  @override
  void dispose() {
    if (_ownsHotspot) _hotspot.stop();
    super.dispose();
  }

  Future<void> _openOfflineNetwork() async {
    if (_startingHotspot) return;
    HapticFeedback.lightImpact();
    setState(() => _startingHotspot = true);
    try {
      final existing = _hotspot.active;
      final info = existing ?? await _hotspot.start();
      if (info == null || !mounted) return;
      _ownsHotspot = true;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OfflineNetworkSheet(
          info: info,
          onStop: () async {
            await _hotspot.stop();
            _ownsHotspot = false;
            if (mounted) Navigator.of(context).pop();
          },
        ),
      );
    } on TransferHotspotException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create an offline Otya network.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _startingHotspot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const TransferScreen(),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: FloatingActionButton.extended(
              heroTag: 'otya-offline-network',
              onPressed: _startingHotspot ? null : _openOfflineNetwork,
              icon: _startingHotspot
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(_startingHotspot ? 'Starting…' : 'Offline network'),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineNetworkSheet extends StatelessWidget {
  const _OfflineNetworkSheet({
    required this.info,
    required this.onStop,
  });

  final OtyaHotspotInfo info;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final password = info.passphrase?.trim();
    final hasPassword = password != null && password.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandBlue.withValues(alpha: .18),
              blurRadius: 34,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              const Icon(
                Icons.wifi_tethering_rounded,
                size: 34,
                color: AppColors.brandCyan,
              ),
              const SizedBox(height: 10),
              const Text(
                'Offline Otya network',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'No router or internet is required. Connect the other phone to this temporary Wi‑Fi, then use Send or Receive normally.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: QrImageView(
                  data: info.wifiQrPayload,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _NetworkRow(label: 'Network', value: info.ssid),
              if (hasPassword)
                _NetworkRow(label: 'Password', value: password),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final text = hasPassword
                        ? 'Otya offline network\nSSID: ${info.ssid}\nPassword: $password'
                        : 'Otya offline network\nSSID: ${info.ssid}';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Network details copied')),
                    );
                  },
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy network details'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue to Send'),
                ),
              ),
              TextButton(
                onPressed: onStop,
                child: const Text('Stop offline network'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
