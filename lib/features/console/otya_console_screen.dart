import 'package:flutter/material.dart';

import 'widgets/otya_ai_mark.dart';

class OtyaConsoleScreen extends StatefulWidget {
  const OtyaConsoleScreen({super.key});

  @override
  State<OtyaConsoleScreen> createState() => _OtyaConsoleScreenState();
}

class _OtyaConsoleScreenState extends State<OtyaConsoleScreen> {
  String _section = 'Overview';
  bool _aiActive = false;

  static const _sections = <_ConsoleSection>[
    _ConsoleSection('Overview', Icons.dashboard_outlined),
    _ConsoleSection('Users', Icons.people_outline),
    _ConsoleSection('Content', Icons.library_music_outlined),
    _ConsoleSection('Insights', Icons.insights_outlined),
    _ConsoleSection('App Control', Icons.tune_outlined),
    _ConsoleSection('Platform', Icons.hub_outlined),
    _ConsoleSection('Security', Icons.shield_outlined),
    _ConsoleSection('Connections', Icons.link_outlined),
    _ConsoleSection('Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OTYA Console'),
      ),
      drawer: compact ? Drawer(child: _leftNavigation(context)) : null,
      body: Row(
        children: [
          if (!compact) SizedBox(width: 252, child: _leftNavigation(context)),
          Expanded(child: _workspace()),
          _utilityRail(),
        ],
      ),
    );
  }

  Widget _leftNavigation(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: 'Search OTYA',
              onTap: () {},
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                for (final item in _sections)
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    selected: _section == item.label,
                    onTap: () {
                      setState(() => _section = item.label);
                      if (Scaffold.of(context).hasDrawer) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspace() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_section, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _subtitleFor(_section),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _summaryCard('System', 'Healthy', Icons.check_circle_outline),
            _summaryCard('Environment', 'Production', Icons.cloud_outlined),
            _summaryCard('Activity', 'Live', Icons.bolt_outlined),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'This workspace is the shell for OTYA management. Detailed pages '
              'for users, content, analytics, releases, backend resources, '
              'security, integrations and settings plug into these categories '
              'without duplicating destinations.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 18),
              Text(title),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _utilityRail() {
    return Material(
      elevation: 2,
      child: SafeArea(
        left: false,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              const SizedBox(height: 8),
              _railButton(Icons.account_circle_outlined, 'Profile', () {}),
              const SizedBox(height: 8),
              Tooltip(
                message: 'OTYA AI',
                child: IconButton(
                  onPressed: () => setState(() => _aiActive = !_aiActive),
                  icon: OtyaAiMark(isActive: _aiActive, size: 30),
                ),
              ),
              _railButton(Icons.notifications_none, 'Notifications', () {}),
              _railButton(Icons.speed_outlined, 'Control Center', () {}),
              const Spacer(),
              _railButton(Icons.help_outline, 'Help', () {}),
              _railButton(Icons.brightness_6_outlined, 'Theme', () {}),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }

  String _subtitleFor(String section) => switch (section) {
        'Users' => 'Accounts, roles, permissions, devices and sessions.',
        'Content' => 'Library, playback, downloads, offline media and processing.',
        'Insights' => 'Analytics, retention, usage, reports and version adoption.',
        'App Control' =>
          'Remote config, feature flags, themes, announcements and releases.',
        'Platform' =>
          'APIs, services, databases, object storage, KV, queues and jobs.',
        'Security' =>
          'Authentication, bot protection, suspicious activity and audit history.',
        'Connections' => 'GitHub, Google, email, Telegram and external APIs.',
        'Settings' =>
          'Project identity, domains, branding, environments and admin access.',
        _ => 'A single view of OTYA status, activity and important metrics.',
      };
}

class _ConsoleSection {
  const _ConsoleSection(this.label, this.icon);

  final String label;
  final IconData icon;
}
