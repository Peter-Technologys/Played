import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/vault_item.dart';

// ── Providers ──────────────────────────────────────────────

final vaultUnlockedProvider = StateProvider<bool>((_) => false);

// ── Lock Screen ────────────────────────────────────────────

class VaultLockScreen extends ConsumerStatefulWidget {
  const VaultLockScreen({super.key});

  @override
  ConsumerState<VaultLockScreen> createState() =>
      _VaultLockScreenState();
}

class _VaultLockScreenState extends ConsumerState<VaultLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on screen open
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        // Fallback to PIN
        _showPinDialog();
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock your Private Vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
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
    // PIN fallback dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(
        onSuccess: () {
          ref.read(vaultUnlockedProvider.notifier).state = true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = ref.watch(vaultUnlockedProvider);

    if (isUnlocked) {
      return const VaultGalleryScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                    color: AppColors.accentViolet, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentViolet.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.accentViolet,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Private Vault',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your private media is locked.\nAuthenticate to access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            if (_isAuthenticating)
              const CircularProgressIndicator(
                  color: AppColors.accentViolet)
            else
              GestureDetector(
                onTap: _authenticate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentViolet.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Unlock with Biometrics',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errorMessage != null) ...
              [
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12),
                ),
              ],
          ],
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
  static const String _pin = '1234'; // Replace with secure storage

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
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Enter PIN',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'SpaceGrotesk')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter your PIN',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary),
              errorText: _error ? 'Incorrect PIN' : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.accentViolet),
              ),
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
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

// ── Vault Gallery Screen ──────────────────────────────────────

class VaultGalleryScreen extends StatefulWidget {
  const VaultGalleryScreen({super.key});

  @override
  State<VaultGalleryScreen> createState() =>
      _VaultGalleryScreenState();
}

class _VaultGalleryScreenState extends State<VaultGalleryScreen> {
  List<VaultItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await PlayedDatabase.instance.getAllVaultItems();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Private Vault',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: const Icon(Icons.lock_rounded,
            color: AppColors.accentViolet),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accentViolet))
          : _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          color: AppColors.textSecondary, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Your vault is empty.',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontFamily: 'SpaceGrotesk'),
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
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) =>
                      _VaultItemCard(item: _items[i]),
                ),
    );
  }
}

class _VaultItemCard extends StatelessWidget {
  final VaultItem item;
  const _VaultItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.mediaType == 'video'
                ? Icons.video_file_rounded
                : Icons.audio_file_rounded,
            color: AppColors.accentViolet,
            size: 40,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.originalPath.split('/').last,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'SpaceGrotesk',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          const Icon(Icons.lock_rounded,
              color: AppColors.textSecondary, size: 14),
        ],
      ),
    );
  }
}
