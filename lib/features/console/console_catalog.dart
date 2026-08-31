import 'package:flutter/material.dart';

class OtyaConsoleSection {
  const OtyaConsoleSection({
    required this.label,
    required this.icon,
    required this.description,
    required this.items,
  });

  final String label;
  final IconData icon;
  final String description;
  final List<String> items;
}

const otyaConsoleSections = <OtyaConsoleSection>[
  OtyaConsoleSection(
    label: 'Overview',
    icon: Icons.dashboard_outlined,
    description: 'A single view of OTYA status, activity and important metrics.',
    items: [
      'Dashboard',
      'Key metrics',
      'Recent system activity',
      'Health summary',
    ],
  ),
  OtyaConsoleSection(
    label: 'Users',
    icon: Icons.people_outline,
    description: 'Accounts, roles, permissions, devices and sessions.',
    items: [
      'Accounts',
      'Roles & permissions',
      'Devices',
      'Sessions',
      'Account actions',
      'User reports',
    ],
  ),
  OtyaConsoleSection(
    label: 'Content',
    icon: Icons.library_music_outlined,
    description: 'Library, playback, downloads, offline media and processing.',
    items: [
      'Music & media library',
      'Playback activity',
      'Downloads',
      'Offline content',
      'Media processing',
      'Playback problems',
    ],
  ),
  OtyaConsoleSection(
    label: 'Insights',
    icon: Icons.insights_outlined,
    description: 'Analytics, retention, usage, reports and version adoption.',
    items: [
      'Active users',
      'Retention',
      'Usage trends',
      'Playback trends',
      'Download analytics',
      'AI usage',
      'Reports',
      'App-version adoption',
      'Crash & error trends',
    ],
  ),
  OtyaConsoleSection(
    label: 'App Control',
    icon: Icons.tune_outlined,
    description: 'Configuration, experience, announcements and releases.',
    items: [
      'Remote config',
      'Feature flags',
      'Themes',
      'Maintenance mode',
      'Announcements',
      'Releases & versions',
      'Rollout',
      'Rollback',
      'Feature rollout targeting',
    ],
  ),
  OtyaConsoleSection(
    label: 'Platform',
    icon: Icons.hub_outlined,
    description: 'Backend services, data, storage and operational resources.',
    items: [
      'APIs',
      'Workers & services',
      'D1 database',
      'R2 object storage',
      'KV cache',
      'Queues',
      'Webhooks',
      'Background jobs',
      'Backup & restore status',
      'API usage & rate limits',
    ],
  ),
  OtyaConsoleSection(
    label: 'Security',
    icon: Icons.shield_outlined,
    description: 'Authentication, protection, audit and account safety.',
    items: [
      'Authentication',
      'Turnstile / bot protection',
      'Suspicious activity',
      'Audit history',
      'Revoked sessions',
      'Security controls',
      'Admin action history',
    ],
  ),
  OtyaConsoleSection(
    label: 'Connections',
    icon: Icons.link_outlined,
    description: 'Connected services and external APIs.',
    items: [
      'GitHub',
      'Google',
      'Resend / email',
      'Telegram',
      'External APIs',
    ],
  ),
  OtyaConsoleSection(
    label: 'Settings',
    icon: Icons.settings_outlined,
    description: 'Project identity, environments, access and developer settings.',
    items: [
      'Project details',
      'Domains',
      'Branding',
      'App identifiers',
      'Production / staging',
      'Team & admin access',
      'Developer configuration',
      'Data export tools',
    ],
  ),
];
