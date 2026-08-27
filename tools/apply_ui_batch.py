from pathlib import Path

# 1) Music and video libraries: let the global image/story wallpaper show through.
for path in [
    Path('lib/features/music/presentation/music_tab_screen.dart'),
    Path('lib/features/video/presentation/video_tab_screen.dart'),
]:
    s = path.read_text()
    imp = "import '../../../shared/widgets/wallpaper_scaffold.dart';\n"
    anchor = "import '../../../shared/widgets/permission_denied_screen.dart';\n"
    if imp not in s:
        s = s.replace(anchor, anchor + imp)
    s = s.replace(
        "    return Scaffold(\n      backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n      body: SafeArea(",
        "    return WallpaperScaffold(\n      body: SafeArea(",
        1,
    )
    s = s.replace(
        "    return Scaffold(\n      backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n      body: SafeArea(\n",
        "    return WallpaperScaffold(\n      body: SafeArea(\n",
        1,
    )
    path.write_text(s)

# 2) Hub: put tools directly on the page as a compact 3 x 3 grid.
p = Path('lib/features/my_space/presentation/my_space_hub_screen.dart')
s = p.read_text()
s = s.replace("    final featured = tools.take(4).toList();", "    final featured = tools.take(9).toList();")
old_header = '''                child: Row(\n                  children: [\n                    Expanded(\n                      child: Text(\n                        'Quick actions',\n                        style: TextStyle(\n                          fontSize: 17,\n                          fontWeight: FontWeight.w800,\n                          color: AppColors.textPrimaryOf(context),\n                        ),\n                      ),\n                    ),\n                    TextButton.icon(\n                      onPressed: () => _showAllTools(context, tools),\n                      icon: const Icon(Icons.grid_view_rounded, size: 17),\n                      label: const Text('All tools'),\n                    ),\n                  ],\n                ),'''
new_header = '''                child: Text(\n                  'Tools',\n                  style: TextStyle(\n                    fontSize: 17,\n                    fontWeight: FontWeight.w800,\n                    color: AppColors.textPrimaryOf(context),\n                  ),\n                ),'''
s = s.replace(old_header, new_header)
s = s.replace("                  crossAxisCount: 2,\n                  crossAxisSpacing: 12,\n                  mainAxisSpacing: 12,\n                  childAspectRatio: 1.7,", "                  crossAxisCount: 3,\n                  crossAxisSpacing: 9,\n                  mainAxisSpacing: 9,\n                  childAspectRatio: 0.92,")
p.write_text(s)

# 3) Theme selector: smaller cards in two columns.
p = Path('lib/features/settings/presentation/theme_selection_screen.dart')
s = p.read_text()
s = s.replace("        height: 220,", "        height: 180,", 1)
old_list = '''          else\n            ..._themes.map((theme) => Padding(\n                  padding: const EdgeInsets.only(bottom: 12),\n                  child: _StoryThemeCard(\n                    theme: theme,\n                    active: activeId == theme.id,\n                    onInstall: () => _install(theme),\n                  ),\n                )),'''
new_grid = '''          else\n            GridView.builder(\n              shrinkWrap: true,\n              physics: const NeverScrollableScrollPhysics(),\n              itemCount: _themes.length,\n              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(\n                crossAxisCount: 2,\n                crossAxisSpacing: 10,\n                mainAxisSpacing: 10,\n                childAspectRatio: 0.72,\n              ),\n              itemBuilder: (context, index) {\n                final theme = _themes[index];\n                return _StoryThemeCard(\n                  theme: theme,\n                  active: activeId == theme.id,\n                  onInstall: () => _install(theme),\n                );\n              },\n            ),'''
s = s.replace(old_list, new_grid)
s = s.replace("      height: 250,\n", "", 1)
s = s.replace("              padding: const EdgeInsets.all(18),", "              padding: const EdgeInsets.all(12),")
s = s.replace("                      fontSize: 21,", "                      fontSize: 15,")
s = s.replace("                    maxLines: 3,", "                    maxLines: 2,")
s = s.replace("                      fontSize: 12,", "                      fontSize: 10.5,", 1)
s = s.replace("                  const SizedBox(height: 14),", "                  const SizedBox(height: 8),", 1)
p.write_text(s)
