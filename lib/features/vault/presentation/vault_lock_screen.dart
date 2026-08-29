import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/models/vault_item.dart';
import '../../../core/services/vault_service.dart';
import '../../player/presentation/mini_player.dart';
import '../../player/presentation/queue_screen.dart';

const _pinKey = 'vault_pin_hash';
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _sessionTtl = Duration(minutes: 5);

final vaultUnlockedProvider = StateProvider<bool>((_) => false);

class VaultLockScreen extends ConsumerStatefulWidget {
  const VaultLockScreen({super.key});

  @override
  ConsumerState<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends ConsumerState<VaultLockScreen>
    with WidgetsBindingObserver {
  static DateTime? _lastUnlock;

  final _localAuth = LocalAuthentication();
  bool _checking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_expired) ref.read(vaultUnlockedProvider.notifier).state = false;
      if (!ref.read(vaultUnlockedProvider)) _unlockWithDevice();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _expired =>
      _lastUnlock == null || DateTime.now().difference(_lastUnlock!) > _sessionTtl;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _expired) {
      ref.read(vaultUnlockedProvider.notifier).state = false;
    }
  }

  void _markUnlocked() {
    _lastUnlock = DateTime.now();
    ref.read(vaultUnlockedProvider.notifier).state = true;
  }

  Future<void> _unlockWithDevice() async {
    if (_checking) return;
    setState(() { _checking = true; _message = null; });
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        if (mounted) setState(() => _message = 'Use your Private PIN to continue.');
        return;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock OTYA Private',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        HapticFeedback.mediumImpact();
        _markUnlocked();
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Device authentication was unavailable. Use your Private PIN instead.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _unlockWithPin() async {
    final stored = await _storage.read(key: _pinKey);
    if (!mounted) return;
    final created = stored == null;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PrivatePinDialog(create: created),
    );
    if (result == true) _markUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(vaultUnlockedProvider)) {
      return const _PrivateLibrary();
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(vaultUnlockedProvider.notifier).state = false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/myspace'),
          ),
          title: const Text('Private'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cardOf(context),
                    border: Border.all(color: AppColors.accent.withValues(alpha: .45)),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 42, color: AppColors.accent),
                ),
                const SizedBox(height: 22),
                const Text('OTYA Private', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                  'Protected media stays inside OTYA app-private storage until you restore it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.45, color: AppColors.textSecondary),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _unlockWithDevice,
                    icon: _checking
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint_rounded),
                    label: const Text('Unlock with device security'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _unlockWithPin, child: const Text('Use Private PIN')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivatePinDialog extends StatefulWidget {
  const _PrivatePinDialog({required this.create});
  final bool create;

  @override
  State<_PrivatePinDialog> createState() => _PrivatePinDialogState();
}

class _PrivatePinDialogState extends State<_PrivatePinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final now = DateTime.now();
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) {
      setState(() => _error = 'Too many attempts. Try again shortly.');
      return;
    }
    final pin = _pin.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Use a 4–6 digit PIN.');
      return;
    }

    setState(() { _busy = true; _error = null; });
    try {
      if (widget.create) {
        if (pin != _confirm.text) {
          setState(() => _error = 'PINs do not match.');
          return;
        }
        await _savePin(pin);
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final ok = await _verifyPin(pin);
      if (ok) {
        if (mounted) Navigator.pop(context, true);
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
          _failedAttempts = 0;
        }
        _pin.clear();
        if (mounted) setState(() => _error = 'Incorrect PIN.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.create ? 'Create Private PIN' : 'Enter Private PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: InputDecoration(labelText: widget.create ? 'New PIN' : 'PIN', errorText: _error),
              onSubmitted: (_) => widget.create ? null : _submit(),
            ),
            if (widget.create) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(widget.create ? 'Create' : 'Unlock')),
        ],
      );
}

Future<void> _savePin(String pin) async {
  final random = Random.secure();
  final salt = List<int>.generate(16, (_) => random.nextInt(256));
  final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
  await _storage.write(key: _pinKey, value: '${base64UrlEncode(salt)}:$digest');
}

Future<bool> _verifyPin(String pin) async {
  final stored = await _storage.read(key: _pinKey);
  if (stored == null) return false;

  if (!stored.contains(':')) {
    // Migrate the original unsalted SHA-256 format after the next successful unlock.
    final legacy = sha256.convert(utf8.encode(pin)).toString();
    final ok = _constantTimeEqual(stored, legacy);
    if (ok) await _savePin(pin);
    return ok;
  }

  final parts = stored.split(':');
  if (parts.length != 2) return false;
  try {
    final salt = base64Url.decode(parts[0]);
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    return _constantTimeEqual(parts[1], digest);
  } catch (_) {
    return false;
  }
}

bool _constantTimeEqual(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

class _PrivateLibrary extends ConsumerStatefulWidget {
  const _PrivateLibrary();

  @override
  ConsumerState<_PrivateLibrary> createState() => _PrivateLibraryState();
}

class _PrivateLibraryState extends ConsumerState<_PrivateLibrary>
    with WidgetsBindingObserver {
  List<VaultItem> _items = const [];
  int _size = 0;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(vaultUnlockedProvider.notifier).state = false;
    }
  }

  Future<void> _refresh() async {
    final items = VaultService.instance.getAllItems();
    final size = await VaultService.instance.getVaultSize();
    if (!mounted) return;
    setState(() {
      _items = items;
      _size = size;
      _loading = false;
    });
  }

  Future<void> _restore(VaultItem item) async {
    setState(() => _message = null);
    try {
      await VaultService.instance.unlockItem(item.mediaId);
      await _refresh();
      if (mounted) setState(() => _message = 'Restored to its original folder.');
    } catch (_) {
      if (mounted) setState(() => _message = 'OTYA could not restore that file.');
    }
  }

  Future<void> _delete(VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete protected file?'),
        content: const Text('This permanently removes the copy stored in OTYA Private. It cannot be restored after deletion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VaultService.instance.deleteFromVault(item.mediaId);
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _message = 'OTYA could not delete that protected file.');
    }
  }

  Future<void> _play(VaultItem item) async {
    final file = File(item.encryptedPath);
    if (!await file.exists()) {
      if (mounted) setState(() => _message = 'This protected file is missing from device storage.');
      return;
    }
    final fileName = item.originalPath.replaceAll('\\', '/').split('/').last;
    final media = MediaItem(
      id: 'private:${item.mediaId}',
      title: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      fileName: fileName,
      filePath: item.encryptedPath,
      isVideo: item.mediaType == 'video',
      addedAt: item.lockedAt,
      fileSizeBytes: await file.length(),
    );
    if (!mounted) return;
    if (media.isVideo) {
      context.push('/player/video', extra: media);
    } else {
      ref.read(queueProvider.notifier).setQueue([media]);
      ref.read(miniPlayerItemProvider.notifier).state = media;
      context.push('/player/audio', extra: media);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              ref.read(vaultUnlockedProvider.notifier).state = false;
              context.canPop() ? context.pop() : context.go('/myspace');
            },
          ),
          title: const Text('Private'),
          actions: [
            IconButton(
              tooltip: 'Lock now',
              onPressed: () => ref.read(vaultUnlockedProvider.notifier).state = false,
              icon: const Icon(Icons.lock_outline_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: AppColors.accent),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${_items.length} protected file${_items.length == 1 ? '' : 's'}')),
                          Text(_formatBytes(_size), style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 10),
                      Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 70),
                        child: Column(
                          children: [
                            Icon(Icons.lock_open_rounded, size: 54, color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text('Private is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            Text('Move media to Private from the player or supported file actions.', textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    else
                      ..._items.map((item) {
                        final name = item.originalPath.replaceAll('\\', '/').split('/').last;
                        return Card(
                          child: ListTile(
                            onTap: () => _play(item),
                            leading: Icon(item.mediaType == 'video' ? Icons.movie_rounded : Icons.music_note_rounded, color: AppColors.accent),
                            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('Protected ${_shortDate(item.lockedAt)}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'restore') _restore(item);
                                if (action == 'delete') _delete(item);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'restore', child: Text('Restore to original folder')),
                                PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _shortDate(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
