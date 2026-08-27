from pathlib import Path

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        print(f"[skip] {label}: pattern not found")
        return text
    print(f"[ok] {label}")
    return text.replace(old, new, 1)

# Music library: let the selected wallpaper/story background show through.
p = Path("lib/features/music/presentation/music_tab_screen.dart")
s = p.read_text()
anchor = "import '../../../shared/widgets/permission_denied_screen.dart';\n"
imp = "import '../../../shared/widgets/wallpaper_scaffold.dart';\n"
if imp not in s:
    s = s.replace(anchor, anchor + imp)
s = replace_once(
    s,
    "    return Scaffold(\n      backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n      body: SafeArea(",
    "    return WallpaperScaffold(\n      body: SafeArea(",
    "music wallpaper scaffold",
)
p.write_text(s)

# Video library: same wallpaper foundation.
p = Path("lib/features/video/presentation/video_tab_screen.dart")
s = p.read_text()
anchor = "import '../../../shared/widgets/permission_denied_screen.dart';\n"
imp = "import '../../../shared/widgets/wallpaper_scaffold.dart';\n"
if imp not in s:
    s = s.replace(anchor, anchor + imp)
s = replace_once(
    s,
    "    return Scaffold(\n      backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n      body: SafeArea(",
    "    return WallpaperScaffold(\n      body: SafeArea(",
    "video wallpaper scaffold",
)
p.write_text(s)

# Hub: 9 direct tools in a 3x3 grid. Keep search in the top bar, but remove
# the separate 'All tools' / More-style entry from the quick-actions section.
p = Path("lib/features/my_space/presentation/my_space_hub_screen.dart")
s = p.read_text()
s = s.replace("    final featured = tools.take(4).toList();", "    final featured = tools.take(9).toList();", 1)
old_header = """                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quick actions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAllTools(context, tools),
                      icon: const Icon(Icons.grid_view_rounded, size: 17),
                      label: const Text('All tools'),
                    ),
                  ],
                ),
"""
new_header = """                child: Text(
                  'Tools',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
"""
s = replace_once(s, old_header, new_header, "hub direct-tools header")
s = replace_once(
    s,
    """                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.7,
                ),
""",
    """                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
""",
    "hub 3x3 grid",
)
p.write_text(s)

# Online theme model: support real image previews and real downloadable wallpapers.
p = Path("lib/core/services/online_theme_service.dart")
s = p.read_text()
s = s.replace(
    "    required this.palette,\n    this.seasonal,\n",
    "    required this.palette,\n    this.previewUrl,\n    this.wallpaperUrl,\n    this.seasonal,\n",
    1,
)
s = s.replace(
    "  final Map<String, String> palette;\n  final Map<String, dynamic>? seasonal;\n",
    "  final Map<String, String> palette;\n  final String? previewUrl;\n  final String? wallpaperUrl;\n  final Map<String, dynamic>? seasonal;\n",
    1,
)
s = s.replace(
    "      palette: rawPalette.map((key, value) => MapEntry(key, value.toString())),\n      seasonal: rawSeasonal is Map<String, dynamic>\n",
    """      palette: rawPalette.map((key, value) => MapEntry(key, value.toString())),
      previewUrl: (json['previewUrl'] as String?)?.trim().isEmpty == false
          ? (json['previewUrl'] as String).trim()
          : null,
      wallpaperUrl: (json['wallpaperUrl'] as String?)?.trim().isEmpty == false
          ? (json['wallpaperUrl'] as String).trim()
          : null,
      seasonal: rawSeasonal is Map<String, dynamic>
""",
    1,
)
s = s.replace(
    "        'palette': palette,\n        if (seasonal != null) 'seasonal': seasonal,\n",
    """        'palette': palette,
        if (previewUrl != null) 'previewUrl': previewUrl,
        if (wallpaperUrl != null) 'wallpaperUrl': wallpaperUrl,
        if (seasonal != null) 'seasonal': seasonal,
""",
    1,
)
p.write_text(s)

# Theme installation: if a theme provides an HTTPS wallpaper image, download a
# bounded copy into app-private storage. Fall back to the old offline recipe if
# the image is unavailable, so themes never break offline playback.
p = Path("lib/core/services/custom_theme_manager.dart")
s = p.read_text()
http_imp = "import 'package:http/http.dart' as http;\n"
if http_imp not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\n" + http_imp)
old_install = """    _themeId = theme.id;
    _storyTheme = manifest;
    _artOpacity = theme.overlay.clamp(0.18, 0.70);
    _artBlur = 0;
    _wallpaperPath = null;
    await _persist();
    notifyListeners();
"""
new_install = """    _themeId = theme.id;
    _storyTheme = manifest;
    _artOpacity = theme.overlay.clamp(0.18, 0.70);
    _artBlur = 0;
    _wallpaperPath = null;

    final imageUrl = theme.wallpaperUrl;
    if (imageUrl != null) {
      final uri = Uri.tryParse(imageUrl);
      if (uri != null && uri.scheme == 'https') {
        try {
          final response = await http.get(uri).timeout(const Duration(seconds: 12));
          final type = response.headers['content-type'] ?? '';
          if (response.statusCode == 200 &&
              response.bodyBytes.isNotEmpty &&
              response.bodyBytes.length <= 6 * 1024 * 1024 &&
              type.toLowerCase().startsWith('image/')) {
            final dir = await getApplicationDocumentsDirectory();
            final dest = Directory('${dir.path}/themes/${theme.id}');
            await dest.create(recursive: true);
            final out = File('${dest.path}/background.jpg');
            await out.writeAsBytes(response.bodyBytes, flush: true);
            _wallpaperPath = out.path;
          }
        } catch (e) {
          debugPrint('[ThemeManager] Image theme download skipped: $e');
        }
      }
    }

    await _persist();
    notifyListeners();
"""
s = replace_once(s, old_install, new_install, "image-backed online theme install")
p.write_text(s)

# Theme screen: compact 2-column catalog; photo image first, procedural recipe
# only as fallback when a catalog item has no image yet.
p = Path("lib/features/settings/presentation/theme_selection_screen.dart")
s = p.read_text()
s = s.replace("        height: 220,", "        height: 180,", 1)
old_list = """          else
            ..._themes.map((theme) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StoryThemeCard(
                    theme: theme,
                    active: activeId == theme.id,
                    onInstall: () => _install(theme),
                  ),
                )),
"""
new_grid = """          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.76,
              ),
              itemCount: _themes.length,
              itemBuilder: (context, index) {
                final theme = _themes[index];
                return _StoryThemeCard(
                  theme: theme,
                  active: activeId == theme.id,
                  onInstall: () => _install(theme),
                );
              },
            ),
"""
s = replace_once(s, old_list, new_grid, "theme two-column grid")
s = s.replace("      height: 250,\n", "", 1)
s = s.replace(
    "            StoryThemeBackground(theme: theme.toJson()),\n",
    """            if ((theme.previewUrl ?? theme.wallpaperUrl) != null)
              Image.network(
                (theme.previewUrl ?? theme.wallpaperUrl)!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    StoryThemeBackground(theme: theme.toJson()),
              )
            else
              StoryThemeBackground(theme: theme.toJson()),
""",
    1,
)
s = s.replace("              padding: const EdgeInsets.all(18),", "              padding: const EdgeInsets.all(12),", 1)
s = s.replace("                      fontSize: 21,", "                      fontSize: 15,", 1)
s = s.replace("                    maxLines: 3,", "                    maxLines: 2,", 1)
s = s.replace("                      fontSize: 12,", "                      fontSize: 10,", 1)
s = s.replace("                  const SizedBox(height: 14),", "                  const SizedBox(height: 8),", 1)
p.write_text(s)

# Make the built-in asset folder available for future bundled image themes.
p = Path("pubspec.yaml")
s = p.read_text()
if "    - assets/themes/\n" not in s:
    s = s.replace("    - assets/animations/\n", "    - assets/animations/\n    - assets/themes/\n")
p.write_text(s)
