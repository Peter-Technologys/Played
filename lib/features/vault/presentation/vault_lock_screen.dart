import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/vault_item.dart';
import '../../../core/services/vault_service.dart';

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
      if (!canCheck && !isSupported) { _showPinDialog(); return; }
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

  void _showPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(
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

class _PinDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _PinDialog({required this.onSuccess});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  bool _error = false;
  static const String _pin = '1234';

  void _verify() {
    if (_controller.text == _pin) {
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
              borderSide:
                  const BorderSide(color: AppColors.accentViolet)),
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
          onPressed: _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentViolet,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Unlock',
              style: TextStyle(color: Colors.white)),
        ),
      ],
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
