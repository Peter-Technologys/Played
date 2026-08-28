import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/update_service.dart';

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await UpdateService.instance.checkForUpdate(force: true);
      if (!mounted) return;
      setState(() {
        _text = info == null || info.changelog.isEmpty
            ? 'You have the latest available version.'
            : info.changelog;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load update information.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What's new")),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
          : _text == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(_text!, style: const TextStyle(height: 1.6)),
                ),
    );
  }
}
