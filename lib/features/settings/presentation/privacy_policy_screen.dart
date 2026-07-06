import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// In-app Privacy Policy screen.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 48),
        child: _PolicyBody(),
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PolicyHeading('OTYA Player — Privacy Policy'),
        _PolicyText('Effective date: June 2026'),
        SizedBox(height: 24),

        _PolicySection(
          title: '1. Who We Are',
          body:
              'OTYA Player is developed and maintained by PeterSmart Link '
              '(petersmartlink.com). '
              'If you have any questions about this policy, contact us at '
              'support@petersmartlink.com.',
        ),

        _PolicySection(
          title: '2. Data We Collect',
          body:
              'OTYA Player is a local media player. We do NOT collect, store, or '
              'sell any personal data.\n\n'
              'The app accesses the following on your device:\n'
              '• Audio and video files — only to display and play your media.\n'
              '• Storage — to read, organise, and (optionally) write media files.\n'
              '• Biometric data — only to unlock the in-app Vault; never leaves your device.\n'
              '• Network — only for optional cloud backup (Appwrite) and ad delivery.\n\n'
              'No usage analytics, crash reports, or behavioural data are sent to us.',
        ),

        _PolicySection(
          title: '3. Permissions We Request',
          body:
              '• READ_MEDIA_AUDIO / READ_MEDIA_VIDEO — to scan and play your local files.\n'
              '• MANAGE_EXTERNAL_STORAGE — to access files on SD cards and all folders.\n'
              '• INTERNET / ACCESS_NETWORK_STATE — for optional cloud sync and ads.\n'
              '• BLUETOOTH / NEARBY_WIFI_DEVICES — for the Air-Drop file-sharing feature.\n'
              '• USE_BIOMETRIC — for Vault unlock; data never leaves the device.\n'
              '• FOREGROUND_SERVICE — to keep audio playing when the screen is off.\n'
              '• POST_NOTIFICATIONS — to show the media playback notification.\n\n'
              'Each permission is requested only when you use the feature that needs it.',
        ),

        _PolicySection(
          title: '4. Third-Party Services',
          body:
              '• Appwrite — optional cloud backup. Data is stored on your own Appwrite '
              'project and is not shared with us.',
        ),

        _PolicySection(
          title: '5. Data Retention & Deletion',
          body:
              'We do not store personal data on our servers. All media and playlists '
              'remain on your device. To delete all app data, uninstall OTYA Player '
              'or clear app data in your device Settings → Apps → OTYA Player → Storage.',
        ),

        _PolicySection(
          title: '6. Children',
          body:
              'OTYA Player is not directed at children under 13. We do not knowingly '
              'collect data from children.',
        ),

        _PolicySection(
          title: '7. Changes to This Policy',
          body:
              'We may update this policy. The effective date at the top will reflect '
              'the latest revision. Continued use of the app after changes constitutes '
              'acceptance of the updated policy.',
        ),

        _PolicySection(
          title: '8. Contact',
          body:
              'Questions or concerns?\n'
              'Email: support@petersmartlink.com\n'
              'Website: https://petersmartlink.com',
        ),

        SizedBox(height: 32),
        _PolicyText('© 2026 PeterSmart Link. All rights reserved.'),
      ],
    );
  }
}

class _PolicyHeading extends StatelessWidget {
  final String text;
  const _PolicyHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          )),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;
  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontFamily: 'Inter',
              )),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary,
                height: 1.65, fontFamily: 'Inter',
              )),
        ],
      ),
    );
  }
}

class _PolicyText extends StatelessWidget {
  final String text;
  const _PolicyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 12, color: AppColors.textMuted,
          fontFamily: 'Inter', height: 1.5,
        ));
  }
}
