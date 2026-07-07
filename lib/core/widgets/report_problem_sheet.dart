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

class _ReportProblemSheetState extends State<ReportProblemSheet> {
  String _category = 'bug';
  bool   _sending  = false;
  bool   _done     = false;
  final  _descCtrl  = TextEditingController();
  final  _emailCtrl = TextEditingController();

  static const _categories = [
    ('bug',        'Bug'),
    ('crash',      'Crash'),
    ('suggestion', 'Suggestion'),
    ('other',      'Other'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please describe the problem before sending.')),
      );
      return;
    }
    setState(() => _sending = true);
    await FeedbackService.instance.submitReport(
      description: _descCtrl.text.trim(),
      category:    _category,
      userEmail:
          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() { _sending = false; _done = true; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _fieldDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.grey[600], fontFamily: 'Inter', fontSize: 13),
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
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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

            if (_done) ...[
              const SizedBox(height: 16),
              const Center(
                child: Text('Report sent! 👍',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, fontFamily: 'Inter',
                    )),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text("We'll look into it.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontFamily: 'Inter',
                    )),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Title
              const Text('Report a Problem',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, fontFamily: 'Inter',
                  )),
              const SizedBox(height: 4),
              Text('Describe what went wrong. We read every report.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontFamily: 'Inter',
                  )),
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
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter', fontSize: 14),
                decoration: _fieldDecor(
                    'e.g. The app crashes when I open a video…'),
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
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter', fontSize: 14),
                decoration:
                    _fieldDecor('Your email (optional — for follow-up)'),
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
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Send Report'),
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
      ),
    );
  }
}
