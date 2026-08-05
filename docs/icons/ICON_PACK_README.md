# Coheronia Icon and Favicon Pack

Concept: a compact constellation sigil with one warm hearth-star. It is meant to feel like Coheronia without relying on detailed character art: night, settlement, progression, stars, and a little mythic navigation.

> **Repo layout note.** In this repository the pack is **flattened** into
> `docs/icons/` — every PNG and web file listed below sits directly in
> `docs/icons/` (there are no `png/`, `web/`, or `preview/` subfolders); only the
> editable masters live under `docs/icons/source/`. The contact-sheet `preview`
> image is not committed. The paths in the table below are shown relative to
> `docs/icons/`.

## Files

| Path (under `docs/icons/`) | Purpose |
| --- | --- |
| `source/coheronia-constellation-icon.svg` | Master square icon with background (also used as the Godot window icon, `res://icon.svg`) |
| `source/coheronia-constellation-mark-transparent.svg` | Transparent constellation-only mark |
| `favicon-16x16.png` | Browser favicon |
| `favicon-32x32.png` | Browser favicon |
| `favicon-48x48.png` | Windows/browser fallback |
| `favicon-64x64.png` | Larger browser/UI fallback |
| `icon-128x128.png` | General app/icon use |
| `apple-touch-icon.png` | iOS home screen icon, 180x180 |
| `android-chrome-192x192.png` | PWA/Android icon |
| `android-chrome-512x512.png` | PWA/Android icon |
| `maskable-icon-512x512.png` | PWA maskable icon with safe padding |
| `transparent-mark-512x512.png` | Transparent constellation mark |
| `favicon.ico` | Multi-size `.ico` favicon (also copied to `docs/favicon.ico`) |
| `favicon.svg` | SVG favicon (also copied to `docs/favicon.svg`) |
| `site.webmanifest` | Web app manifest |
| `html-head-snippet.html` | Copy-ready head tags (reference) |

## Install Notes

These files already ship in the repo. The wiki HTML pages link the favicons/manifest
automatically — `scripts/wiki/generate_wiki.py` injects the `<head>` tags at the
correct per-page relative depth to `docs/icons/`, and `docs/favicon.ico` /
`docs/favicon.svg` cover a site served from the `docs/` root. The Godot window icon
(`res://icon.svg`, `application/config/icon`) is the master constellation SVG.

For Godot or game-launcher exports, start with `icon-128x128.png`,
`android-chrome-192x192.png`, or `android-chrome-512x512.png` depending on the target.

## Art Direction Notes

- Keep the constellation shape intact across future variants.
- Avoid adding letters inside the favicon; text will collapse at 16px and 32px.
- The warm star can become the settlement/hearth motif if the UI later needs a matching loading spinner, save icon, or desktop launcher badge.
