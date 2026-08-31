import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'console_catalog.dart';
import 'widgets/otya_ai_mark.dart';

class OtyaConsoleScreen extends StatefulWidget {
  const OtyaConsoleScreen({super.key});

  @override
  State<OtyaConsoleScreen> createState() => _OtyaConsoleScreenState();
}

class _OtyaConsoleScreenState extends State<OtyaConsoleScreen> {
  String _section = 'Overview';
  String _query = '';
  bool _aiActive = false;

  OtyaConsoleSection get _selected => otyaConsoleSections.firstWhere(
        (item) => item.label == _section,
        orElse: () => otyaConsoleSections.first,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    return Scaffold(
      appBar: AppBar(title: const Text('OTYA Console')),
      drawer: compact ? Drawer(child: _leftNavigation(context)) : null,
      body: Row(
        children: [
          if (!compact) SizedBox(width: 264, child: _leftNavigation(context)),
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
              hintText: 'Search OTYA Console',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _query.isEmpty ? _sectionList(context) : _searchResults(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        for (final item in otyaConsoleSections)
          ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            selected: _section == item.label,
            onTap: () => _selectSection(context, item.label),
          ),
      ],
    );
  }

  Widget _searchResults(BuildContext context) {
    final needle = _query.toLowerCase();
    final matches = <({OtyaConsoleSection section, String item})>[];
    for (final section in otyaConsoleSections) {
      if (section.label.toLowerCase().contains(needle)) {
        matches.add((section: section, item: section.label));
      }
      for (final item in section.items) {
        if (item.toLowerCase().contains(needle)) {
          matches.add((section: section, item: item));
        }
      }
    }

    if (matches.isEmpty) {
      return const Center(child: Text('No matching console tools.'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final match in matches)
          ListTile(
            leading: Icon(match.section.icon),
            title: Text(match.item),
            subtitle: match.item == match.section.label
                ? null
                : Text(match.section.label),
            onTap: () => _selectSection(context, match.section.label),
          ),
      ],
    );
  }

  void _selectSection(BuildContext context, String label) {
    setState(() {
      _section = label;
      _query = '';
    });
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.hasDrawer ?? false) Navigator.maybePop(context);
  }

  Widget _workspace() {
    final selected = _selected;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(selected.label, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(selected.description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        if (selected.label == 'Overview') ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _summaryCard('System', 'Ready', Icons.check_circle_outline),
              _summaryCard('Environment', 'Production', Icons.cloud_outlined),
              _summaryCard('Console', 'Connected', Icons.hub_outlined),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Text('Tools', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 560
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in selected.items)
                  SizedBox(
                    width: cardWidth,
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        leading: Icon(selected.icon),
                        title: Text(item),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showToolDetails(selected.label, item),
                      ),
                    ),
                  ),
              ],
            );
          },
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
              _railButton(
                Icons.account_circle_outlined,
                'Profile',
                () => context.push('/profile'),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: 'OTYA AI',
                child: IconButton(
                  onPressed: () async {
                    setState(() => _aiActive = true);
                    await context.push('/support');
                    if (mounted) setState(() => _aiActive = false);
                  },
                  icon: OtyaAiMark(isActive: _aiActive, size: 30),
                ),
              ),
              _railButton(
                Icons.notifications_none,
                'Notifications',
                _showNotifications,
              ),
              _railButton(
                Icons.speed_outlined,
                'Control Center',
                _showControlCenter,
              ),
              const Spacer(),
              _railButton(Icons.help_outline, 'Help', () => context.push('/about')),
              _railButton(
                Icons.brightness_6_outlined,
                'Theme',
                () => context.push('/theme'),
              ),
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

  void _showToolDetails(String section, String item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$item belongs only under $section. Its live backend action can be wired here without creating a duplicate destination.'),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
    _showUtilitySheet(
      'Notifications',
      const [
        'System alerts',
        'Security alerts',
        'Release alerts',
        'Failed jobs',
        'User reports',
        'Integration warnings',
      ],
    );
  }

  void _showControlCenter() {
    _showUtilitySheet(
      'Control Center',
      const [
        'System & service health',
        'Recent operational activity',
        'Maintenance status',
        'Queue & job status',
        'Storage & database health',
        'Incident status',
      ],
    );
  }

  void _showUtilitySheet(String title, List<String> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final item in items)
              ListTile(
                title: Text(item),
                trailing: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      ),
    );
  }
}
