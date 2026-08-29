import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/otya_support_service.dart';

class OtyaSupportScreen extends StatefulWidget {
  const OtyaSupportScreen({super.key});

  @override
  State<OtyaSupportScreen> createState() => _OtyaSupportScreenState();
}

class _OtyaSupportScreenState extends State<OtyaSupportScreen> {
  final _controller = TextEditingController();
  final _emailController = TextEditingController();
  final _service = OtyaSupportService.instance;

  String? _answer;
  String? _lastQuestion;
  String? _error;
  bool _busy = false;
  bool _handoffAvailable = false;

  Future<void> _ask([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _busy) return;
    _controller.text = question;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
      _handoffAvailable = false;
      _lastQuestion = question;
    });
    try {
      final reply = await _service.ask(question);
      if (!mounted) return;
      setState(() {
        _answer = reply.answer;
        _handoffAvailable = reply.handoffAvailable || !reply.inScope;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ask OTYA is unavailable right now. Your local player still works normally.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handoff() async {
    final question = _lastQuestion?.trim() ?? '';
    if (question.isEmpty) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardOf(context),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Talk to OTYA support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('Enter your email. OTYA will send your question to support and create a ticket.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email',
                filled: true,
                fillColor: Theme.of(sheetContext).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Send to support'),
              ),
            ),
          ],
        ),
      ),
    );
    if (sent != true || !mounted) return;
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ticket = await _service.handoff(question: question, email: email);
      if (!mounted) return;
      setState(() {
        _answer = 'Your question was sent to OTYA support. Ticket ${ticket.id}. We can reply to $email.';
        _handoffAvailable = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the support request. Try again when you are online.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask OTYA')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Text('How can OTYA help?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1, color: AppColors.textPrimaryOf(context))),
            const SizedBox(height: 8),
            const Text('Ask about playback, music, video, files, transfer, converter, private media, themes, storage, account, updates or troubleshooting.', style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Prompt(label: 'Videos missing', onTap: () => _ask('Why are some videos missing from OTYA?')),
                _Prompt(label: 'Transfer help', onTap: () => _ask('How do I send or receive files with OTYA Transfer?')),
                _Prompt(label: 'Subtitles', onTap: () => _ask('How do I add subtitles to a video?')),
                _Prompt(label: 'Audio problem', onTap: () => _ask('Why is my music not playing correctly?')),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask about OTYA…',
                filled: true,
                fillColor: AppColors.cardOf(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.borderOf(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.borderOf(context))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _ask(),
                icon: _busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                label: Text(_busy ? 'Checking…' : 'Ask OTYA'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Text(_answer!, style: TextStyle(fontSize: 14, height: 1.55, color: AppColors.textPrimaryOf(context))),
              ),
            ],
            if (_handoffAvailable) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _handoff,
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Talk to support'),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Ask OTYA does not need access to your local music or video list. Never send passwords, verification codes or secret keys.', style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Prompt({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ActionChip(
        label: Text(label),
        avatar: const Icon(Icons.help_outline_rounded, size: 17),
        onPressed: onTap,
      );
}
