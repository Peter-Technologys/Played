import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/feedback_service.dart';
import '../../app/theme/app_colors.dart';

/// Bottom sheet for rating Otya (1–5 stars + optional comment).
///
/// Auto-show with connection check:
///   await RateUsSheet.showIfAppropriate(context);
///
/// Manual show:
///   RateUsSheet.show(context);
class RateUsSheet extends StatefulWidget {
  const RateUsSheet._();

  /// Shows the sheet only when there is a real internet connection AND the
  /// prompt has not already been shown for the current app version.
  static Future<void> showIfAppropriate(BuildContext context) async {
    final should = await FeedbackService.instance.shouldShowRatePrompt();
    if (!should) return;
    await FeedbackService.instance.markRatePromptShown();
    if (context.mounted) await show(context);
  }

  /// Always shows the sheet (e.g. from Settings or Update Dialog).
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const RateUsSheet._(),
    );
  }

  @override
  State<RateUsSheet> createState() => _RateUsSheetState();
}

class _RateUsSheetState extends State<RateUsSheet>
    with SingleTickerProviderStateMixin {
  int _stars = 0;
  bool _sending = false;
  bool _done = false;
  final _commentCtrl = TextEditingController();
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars == 0) {
      HapticFeedback.heavyImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    await FeedbackService.instance.submitRating(
      stars: _stars,
      comment: _commentCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _done = true;
    });
    _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (_done) _buildSuccess() else _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _successScale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.accentGreen,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Thank you! ⭐',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your rating means a lot to us.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Rate Us',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your feedback helps us improve',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final rating = i + 1;
            final filled = i < _stars;
            final starLabel = '$rating ${rating == 1 ? 'star' : 'stars'}';
            return Semantics(
              button: true,
              selected: _stars == rating,
              label: starLabel,
              hint: 'Rate Otya $rating out of 5',
              child: Tooltip(
                message: starLabel,
                child: InkResponse(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _stars = rating);
                  },
                  radius: 26,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: AnimatedScale(
                        scale: filled ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: filled
                              ? const Color(0xFFFFC107)
                              : Colors.grey[600],
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Tell us what you love or what we can improve…',
            hintStyle: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'Inter',
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.accent,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  const Color(0xFFFFC107).withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                fontFamily: 'Inter',
              ),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : const Text('Send Rating'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[500],
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        ),
      ],
    );
  }
}
