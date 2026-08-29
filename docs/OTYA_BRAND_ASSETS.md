# OTYA Brand Assets

This repository contains the production OTYA brand system generated from `assets/branding/otya_logo_master.svg`.

## Primary brand rule

When the OTYA symbol and brand name appear **on the same line**, the symbol itself is the letter **O**. The horizontal wordmark must therefore be:

**[OTYA symbol] + TYA**

Do not place the symbol beside a second written `O`.

When the symbol is separated from the name vertically, for example on a splash screen, the full word `OTYA` may appear underneath.

## Generated locations

- `assets/icons/` — Flutter in-app master logo, monochrome mark, horizontal wordmark, stacked logo.
- `assets/animations/` — OTYA AI-thinking visual keyframes.
- `assets/branding/` — master SVG and splash reference.
- `android/app/src/main/res/drawable*` — Android logo, splash and notification drawables.
- `android/app/src/main/res/mipmap*` — Android launcher and adaptive icons.
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — iPhone, iPad and App Store icon sizes.
- `web/` and `web/icons/` — favicon, Apple touch icon and PWA/maskable icons.
- `store_assets/` — 512×512 Google Play icon, 1024×1024 master icon and 1024×500 feature graphic.

## OTYA AI thinking motion language

The OTYA symbol should remain recognizable while the AI is active. Use the same symbol for these states:

1. **Listening** — slow breathing glow.
2. **Thinking** — light sweep around the loop plus subtle orbiting particles.
3. **Responding** — smooth pulse with slightly increased brightness.
4. **Success** — brief warm highlight, then return to idle.
5. **Error/offline** — keep the geometry intact; reduce saturation rather than changing the logo shape.

The generated `otya_ai_thinking_01.png` through `04.png` files are visual keyframes. In Flutter, animate the canonical logo rather than playing a large frame-by-frame raster animation whenever possible.

## Colors

- Deep navy: `#030516`
- Electric blue: `#146BFF`
- Violet: `#6A19FF`
- Magenta: `#E81CFF`
- Orange: `#FF8A00`

The master logo also carries cyan and yellow highlights to preserve the full luminous gradient.

## Regenerating

Run:

```bash
python tools/generate_otya_brand_assets.py
```

The GitHub workflow `generate-otya-brand-assets.yml` regenerates and commits the platform-specific files on the OTYA brand-assets branch.
