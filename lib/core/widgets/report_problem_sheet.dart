import 'package:flutter/material.dart';
import '../services/feedback_service.dart';
import '../../app/theme/app_colors.dart';

/// Bottom sheet for reporting a problem in OTYA Player.
/// Usage: ReportProblemSheet.show(context);
class ReportProblemSheet extends StatefulWidget {
  const ReportProblemSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ReportProblemSheet._(),
    );
  }

  @override
  State<ReportProblemSheet> createState() => _ReportProblemSheetState();
}

class _ReportProblemSheetState extends State<ReportProblemSheet>
    with SingleTickerProviderStateMixin {
  String _category = 'bug';
  bool   _sending  = false;
  bool   _done     = false;
  bool   _descError = false;
  final  _descCtrl  = TextEditingController();
  final  _emailCtrl = TextEditingController();
  late final AnimationController _successCtrl;
  late final Animation<double>   _successScale;

  static const _categories = [
    ('bug',        'Bug'),
    ('crash',      'Crash'),
    ('suggestion', 'Suggestion'),
    ('other',      'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _successScale = CurvedAnimation(
      parent: _successCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _emailCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _descError = true);
      return;
    }
    // Dismiss keyboard before submitting
    FocusScope.of(context).unfocus();
    setState(() { _sending = true; _descError = false; });
    await FeedbackService.instance.submitReport(
      description: _descCtrl.text.trim(),
      category:    _category,
      userEmail:
          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() { _sending = false; _done = true; });
    _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _fieldDecor(String hint, {bool hasError = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.grey[600], fontFamily: 'Inter', fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: hasError ? AppColors.error : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: hasError ? AppColors.error : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: hasError ? AppColors.error : AppColors.accent,
              width: 1.5),
        ),
        errorText: hasError ? 'Please describe the problem.' : null,
        errorStyle: const TextStyle(
            color: AppColors.error, fontFamily: 'Inter', fontSize: 11),
        contentPadding: const EdgeInsets.all(14),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom + 16;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (_done)
              _buildSuccess()
            else
              _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _successScale,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.accentGreen, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Report sent! 👍',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 6),
            Text("We'll look into it.",
                style: TextStyle(
                  fontSize: 13, color: Colors.grey[500], fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Report a Problem',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary, fontFamily: 'Inter',
            )),
        const SizedBox(height: 4),
        Text('Describe what went wrong. We read every report.',
            style: TextStyle(
              fontSize: 13, color: Colors.grey[500], fontFamily: 'Inter')),
        const SizedBox(height: 20),

        // Category
        const Text('Category',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, fontFamily: 'Inter',
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter', fontSize: 14),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(c.$2),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        const Text('Description',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, fontFamily: 'Inter',
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Inter', fontSize: 14),
          onChanged: (_) {
            if (_descError) setState(() => _descError = false);
          },
          decoration: _fieldDecor(
              'e.g. The app crashes when I open a video…',
              hasError: _descError),
        ),
        const SizedBox(height: 16),

        // Email (optional)
        const Text('Your Email (optional)',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, fontFamily: 'Inter',
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Inter', fontSize: 14),
          decoration: _fieldDecor('Your email (optional — for follow-up)'),
        ),
        const SizedBox(height: 20),

        // Send button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Colors.redAccent.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15, fontFamily: 'Inter'),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Send Report'),
          ),
        ),
        const SizedBox(height: 8),

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
    );
  }
}
