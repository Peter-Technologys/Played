import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/feedback_service.dart';
import '../../app/theme/app_colors.dart';

/// Bottom sheet for rating OTYA Player (1–5 stars + optional comment).
///
/// Auto-show with connection check:
///   await RateUsSheet.showIfAppropriate(context);
///
/// Manual show:
///   RateUsSheet.show(context);
class RateUsSheet extends StatefulWidget {
  const RateUsSheet._();

  /// Shows the sheet only when there is an internet connection AND the prompt
  /// has not already been shown for the current app version.
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

class _RateUsSheetState extends State<RateUsSheet> {
  int    _stars   = 0;
  bool   _sending = false;
  bool   _done    = false;
  final  _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a star rating first.')),
      );
      return;
    }
    setState(() => _sending = true);
    await FeedbackService.instance.submitRating(
      stars:   _stars,
      comment: _commentCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() { _sending = false; _done = true; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_done) ...[
            const SizedBox(height: 16),
            const Text('Thank you! ⭐',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 8),
            Text('Your rating means a lot to us.',
                style: TextStyle(
                  fontSize: 13, color: Colors.grey[500], fontFamily: 'Inter')),
            const SizedBox(height: 24),
          ] else ...[
            // Title
            const Text('Rate OTYA Player',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 4),
            Text('Your feedback helps us improve',
                style: TextStyle(
                  fontSize: 13, color: Colors.grey[500], fontFamily: 'Inter')),
            const SizedBox(height: 24),

            // Star selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _stars = i + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFFFC107)
                          : Colors.grey[600],
                      size: 44,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Comment field
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'Tell us what you love or what we can improve…',
                hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Inter', fontSize: 13),
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
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15, fontFamily: 'Inter'),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black))
                    : const Text('Send Rating'),
              ),
            ),
            const SizedBox(height: 10),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 10)),
                child: const Text('Cancel',
                    style: TextStyle(fontFamily: 'Inter')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
