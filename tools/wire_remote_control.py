from pathlib import Path

router = Path('lib/app/router.dart')
s = router.read_text()
anchor = "import '../core/widgets/update_dialog.dart';\n"
remote_import = "import '../core/services/remote_control_service.dart';\n"
if remote_import not in s:
    s = s.replace(anchor, anchor + remote_import)
old = (
    "  static String? _redirect(BuildContext context, GoRouterState state) {\n"
    "    // Auth is optional — OTYA Player works fully offline without an account.\n"
    "    // The auth screen is only reached by explicit navigation (e.g. from Profile).\n"
    "    return null;\n"
    "  }\n"
)
new = (
    "  static String? _redirect(BuildContext context, GoRouterState state) {\n"
    "    final remote = RemoteControlService.instance;\n"
    "    final feature = switch (state.matchedLocation) {\n"
    "      '/airdrop' => 'beam',\n"
    "      '/vault' => 'safe',\n"
    "      '/player/equalizer' => 'equalizer',\n"
    "      '/tools/whatsapp' => 'whatsappTrimmer',\n"
    "      _ => null,\n"
    "    };\n"
    "    if (feature != null && !remote.featureEnabled(feature)) {\n"
    "      return '/myspace';\n"
    "    }\n"
    "    return null;\n"
    "  }\n"
)
if old in s:
    s = s.replace(old, new)
router.write_text(s)

hub = Path('lib/features/my_space/presentation/my_space_hub_screen.dart')
s = hub.read_text()
s = s.replace("import 'package:uuid/uuid.dart';\n", '')
s = s.replace(": () => _signIn(context, ref),", ": () => context.push('/auth'),")
start = s.find('  Future<void> _signIn(BuildContext context, WidgetRef ref) async {')
if start >= 0:
    end = s.find('  Future<void> _runBackup(', start)
    if end >= 0:
        s = s[:start] + s[end:]
hub.write_text(s)
