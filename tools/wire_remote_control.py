from pathlib import Path

hub = Path('lib/features/my_space/presentation/my_space_hub_screen.dart')
s = hub.read_text()
anchor = "import '../../../core/services/cloudflare_service.dart';\n"
remote_import = "import '../../../core/services/remote_control_service.dart';\n"
if remote_import not in s:
    s = s.replace(anchor, anchor + remote_import)

old_start = "  List<_ToolEntry> _tools(WidgetRef ref) => [\n"
new_start = (
    "  List<_ToolEntry> _tools(WidgetRef ref) {\n"
    "    final remote = RemoteControlService.instance;\n"
    "    return [\n"
)
if old_start in s:
    s = s.replace(old_start, new_start, 1)

for label, flag in [
    ("Beam", "beam"),
    ("Safe", "safe"),
    ("Sound", "equalizer"),
    ("Trim", "whatsappTrimmer"),
]:
    marker = "        _ToolEntry(\n"
    pos = s.find("          label: '%s'," % label)
    if pos >= 0:
        start = s.rfind(marker, 0, pos)
        prefix = "        if (remote.featureEnabled('%s'))\n" % flag
        if start >= 0 and s[start-len(prefix):start] != prefix:
            s = s[:start] + prefix + s[start:]

old_end = "        ),\n      ];\n\n  @override\n  Widget build"
new_end = "        ),\n      ];\n  }\n\n  @override\n  Widget build"
if old_end in s:
    s = s.replace(old_end, new_end, 1)

hub.write_text(s)
