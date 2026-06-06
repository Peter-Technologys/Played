import 'dart:convert';
import 'package:async/async.dart' show unawaited;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/vault_item.dart';
import '../../../core/services/vault_service.dart';

// ── PIN helpers: stored as SHA-256 hash in SharedPreferences ──
const _kPinKey = 'vault_pin_hash';

Future<bool> _hasPinSet() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_kPinKey);
}

Future<bool> _verifyPin(String pin) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_kPinKey);
  final hash = sha256.convert(utf8.encode(pin)).toString();
  return stored == hash;
}

Future<void> _savePin(String pin) async {
  final prefs = await SharedPreferences.getInstance();
  final hash = sha256.convert(utf8.encode(pin)).toString();
  await prefs.setString(_kPinKey, hash);
}

final vaultUnlockedProvider = StateProvider<bool>((_) => false);

// ── Lock Screen ────────────────────────────────────────────

class VaultLockScreen extends ConsumerStatefulWidget {
  const VaultLockScreen({super.key});

  @override
  ConsumerState<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends ConsumerState<VaultLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() { _isAuthenticating = true; _errorMessage = null; });
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) { unawaited(_showPinDialog()); return; }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your Private Vault',
        options: const AuthenticationOptions(
            biometricOnly: false, stickyAuth: true),
      );
      if (ok) {
        ref.read(vaultUnlockedProvider.notifier).state = true;
      } else {
        setState(() => _errorMessage = 'Authentication failed. Try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  // Shows PIN dialog — first launch prompts user to create a PIN,
  // subsequent launches verify against the stored SHA-256 hash.
  Future<void> _showPinDialog() async {
    final pinSet = await _hasPinSet();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => pinSet
          ? _PinDialog(
              onSuccess: () =>
                  ref.read(vaultUnlockedProvider.notifier).state = true)
          : _SetPinDialog(
              onSuccess: () =>
                  ref.read(vaultUnlockedProvider.notifier).state = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(vaultUnlockedProvider)) return const VaultGalleryScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon with glow
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.accentViolet, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accentViolet.withOpacity(0.35),
                        blurRadius: 32,
                        spreadRadius: 4)
                  ],
                ),
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.accentViolet, size: 44),
              ).animate().scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 28),

              const Text('Private Vault',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'SpaceGrotesk',
                  )).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              const Text(
                'Your private media is encrypted.\nAuthenticate to access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 40),

              if (_isAuthenticating)
                const CircularProgressIndicator(
                    color: AppColors.accentViolet)
              else
                GestureDetector(
                  onTap: _authenticate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accentViolet,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accentViolet.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint_rounded,
                            color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text('Unlock with Biometrics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'SpaceGrotesk',
                            )),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 16),

              // PIN fallback
              TextButton(
                onPressed: _showPinDialog,
                child: const Text('Use PIN instead',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontFamily: 'SpaceGrotesk')),
              ),

              if (_errorMessage != null) ...
                [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                        textAlign: TextAlign.center),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── PIN Dialog ───────────────────────────────────────────────

// ── Enter PIN dialog (verifies against stored SHA-256 hash) ────────
class _PinDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _PinDialog({required this.onSuccess});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  bool _error = false;
  bool _loading = false;

  Future<void> _verify() async {
    setState(() { _loading = true; _error = false; });
    final ok = await _verifyPin(_controller.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      setState(() => _error = true);
      _controller.clear();
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Enter PIN',
          style: TextStyle(
              color: AppColors.textPrimary, fontFamily: 'SpaceGrotesk')),
      content: TextField(
        controller: _controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Enter your PIN',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          counterText: '',
          errorText: _error ? 'Incorrect PIN' : null,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accentViolet)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error)),
        ),
        onSubmitted: (_) => _verify(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentViolet,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Unlock', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Set PIN dialog (shown on first vault access) ──────────────────
class _SetPinDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _SetPinDialog({required this.onSuccess});

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;

  Future<void> _save() async {
    if (_pin1.text.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    if (_pin1.text != _pin2.text) {
      setState(() => _error = 'PINs do not match');
      _pin2.clear();
      return;
    }
    await _savePin(_pin1.text);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  void dispose() { _pin1.dispose(); _pin2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Create Vault PIN',
          style: TextStyle(
              color: AppColors.textPrimary, fontFamily: 'SpaceGrotesk')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Set a PIN to protect your Private Vault.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _PinField(controller: _pin1, hint: 'New PIN (4–6 digits)'),
          const SizedBox(height: 12),
          _PinField(controller: _pin2, hint: 'Confirm PIN'),
          if (_error != null) ...[  
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(
                color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentViolet,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Save PIN',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _PinField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        counterText: '',
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accentViolet)),
      ),
    );
  }
}

// ── Vault Gallery ────────────────────────────────────────────

class VaultGalleryScreen extends StatefulWidget {
  const VaultGalleryScreen({super.key});

  @override
  State<VaultGalleryScreen> createState() => _VaultGalleryScreenState();
}

class _VaultGalleryScreenState extends State<VaultGalleryScreen> {
  List<VaultItem> _items = [];
  bool _loading = true;
  int? _vaultSizeBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await PlayedDatabase.instance.getAllVaultItems();
    final size = await VaultService.instance.getVaultSize();
    setState(() {
      _items = items;
      _vaultSizeBytes = size;
      _loading = false;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _removeItem(VaultItem item) async {
    await VaultService.instance.unlockItem(item.mediaId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Private Vault',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 18,
            )),
        actions: [
          if (_vaultSizeBytes != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatSize(_vaultSizeBytes!),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accentViolet,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SpaceGrotesk'),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accentViolet))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.lock_open_rounded,
                            color: AppColors.textSecondary, size: 36),
                      ),
                      const SizedBox(height: 20),
                      const Text('Vault is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'SpaceGrotesk',
                          )),
                      const SizedBox(height: 8),
                      const Text(
                        'Long-press any file and tap\n"Move to Vault" to protect it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => _VaultCard(
                    item: _items[i],
                    onRemove: () => _removeItem(_items[i]),
                  ),
                ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  final VaultItem item;
  final VoidCallback onRemove;
  const _VaultCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isVideo = item.mediaType == 'video';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Thumbnail area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(
                  isVideo
                      ? Icons.video_file_rounded
                      : Icons.audio_file_rounded,
                  color: AppColors.accentViolet,
                  size: 44,
                ),
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.originalPath.split('/').last,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'SpaceGrotesk',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: AppColors.accentViolet, size: 12),
                    const SizedBox(width: 4),
                    const Text('Encrypted',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.accentViolet)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onRemove,
                      child: const Icon(Icons.lock_open_rounded,
                          color: AppColors.textSecondary, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
