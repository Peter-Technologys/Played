import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/custom_theme_manager.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  String? _wallpaperPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _wallpaperPath = CustomThemeManager.instance.wallpaperPath;
  }

  Future<void> _chooseImage() async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2160,
    );
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await CustomThemeManager.instance.setTheme(
        id: 'otya-image',
        artworkPath: picked.path,
        opacity: 0.46,
        blur: 0,
      );
      if (!mounted) return;
      setState(() {
        _wallpaperPath = CustomThemeManager.instance.wallpaperPath;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image theme applied')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not apply that image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _wallpaperPath;
    final hasImage = path != null && File(path).existsSync();

    return WallpaperScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Image Theme',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const Text(
            'ONE APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _chooseImage,
            child: Container(
              height: 360,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accent, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.file(File(path), fit: BoxFit.cover)
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF17111F), Color(0xFF08080B)],
                          ),
                        ),
                      ),
                    Container(color: Colors.black.withValues(alpha: 0.28)),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xB3121218),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saving)
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            else
                              Icon(
                                hasImage
                                    ? Icons.wallpaper_rounded
                                    : Icons.add_photo_alternate_rounded,
                                color: AppColors.accent,
                                size: 32,
                              ),
                            const SizedBox(height: 10),
                            Text(
                              hasImage ? 'Change Background Image' : 'Choose Background Image',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'OTYA uses transparent panels over your image',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xA6101014),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.layers_outlined, color: AppColors.accent, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is the only OTYA theme. Your selected photo stays on the device and becomes the visual background across supported screens.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
