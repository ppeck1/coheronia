# Coheronia Icon and Favicon Pack

Concept: a compact constellation sigil with one warm hearth-star. It is meant to feel like Coheronia without relying on detailed character art: night, settlement, progression, stars, and a little mythic navigation.

## Files

| Path | Purpose |
| --- | --- |
| `source/coheronia-constellation-icon.svg` | Master square icon with background |
| `source/coheronia-constellation-mark-transparent.svg` | Transparent constellation-only mark |
| `png/favicon-16x16.png` | Browser favicon |
| `png/favicon-32x32.png` | Browser favicon |
| `png/favicon-48x48.png` | Windows/browser fallback |
| `png/favicon-64x64.png` | Larger browser/UI fallback |
| `png/icon-128x128.png` | General app/icon use |
| `png/apple-touch-icon.png` | iOS home screen icon, 180x180 |
| `png/android-chrome-192x192.png` | PWA/Android icon |
| `png/android-chrome-512x512.png` | PWA/Android icon |
| `png/maskable-icon-512x512.png` | PWA maskable icon with safe padding |
| `png/transparent-mark-512x512.png` | Transparent constellation mark |
| `web/favicon.ico` | Multi-size `.ico` favicon |
| `web/favicon.svg` | SVG favicon |
| `web/site.webmanifest` | Web app manifest |
| `web/html-head-snippet.html` | Copy-ready head tags |
| `preview/coheronia-icon-preview.png` | Contact sheet preview |

## Install Notes

For most web builds, copy the files from `png/` and `web/` to the site root or public asset directory. Then add the tags from `web/html-head-snippet.html` to the document head.

For Godot or game-launcher use, start with `png/icon-128x128.png`, `png/android-chrome-192x192.png`, or `png/android-chrome-512x512.png` depending on the export target.

## Art Direction Notes

- Keep the constellation shape intact across future variants.
- Avoid adding letters inside the favicon; text will collapse at 16px and 32px.
- The warm star can become the settlement/hearth motif if the UI later needs a matching loading spinner, save icon, or desktop launcher badge.
