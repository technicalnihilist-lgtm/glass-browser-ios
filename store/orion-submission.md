# Orion Store submission

Orion Store (github.com/RookieEnough/Orion-Store) indexes Android apps from a **public**
GitHub repository and its **Releases**. It does not host APKs — it links to the release asset.
Submission goes through their Issue-Ops pipeline (a GitHub issue on their repo) or the
submission form inside the Orion client.

## Requirements checklist

| Requirement | Status |
| --- | --- |
| Repository is public | **No — must be flipped to public**, otherwise the bot cannot read it |
| Release exists with an `.apk` asset | Yes — `v1.0.0`, asset `GlassBrowser.apk` (62 KB, signed) |
| Icon is a direct image link (`.png`) | Yes — `https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/icon.png` |
| `packageName` known | Yes — `com.glass.browser` |
| Submitter owns the repo (provenance check) | Yes — same GitHub account |

## Issue payload

Paste this into a new issue on `RookieEnough/Orion-Store`, or use the client's
*Submit App* form and copy the fields.

```yaml
name: "Glass Browser"
packageName: "com.glass.browser"
repo: "https://github.com/technicalnihilist-lgtm/glass-browser-ios"
icon: "https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/icon.png"
description: "A frosted-glass browser for Android: tabs, private mode, bookmarks, history, reading list and a reader view, wrapped around a single HTML UI."
category: "Browsers"
license: "MIT"
```

## Description (long)

Glass Browser is a browser with a glassmorphism interface. Tabs and private tabs, bookmarks
with folders and favourites, history, a reading list, a reader view, and a settings panel for
theme, search engine, glass transparency, animation speed, bounce, 4D tilt and sound — all
rendered by one self-contained HTML file inside a native shell.

The Android build is a thin WebView host: no analytics, no trackers, no network calls of its
own. It asks for `INTERNET` and `ACCESS_NETWORK_STATE` only, because it browses the web.
Everything you save stays on your device.

## Screenshots (direct links)

- https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/screenshots/01-start.png
- https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/screenshots/02-search.png
- https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/screenshots/03-settings.png
- https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/screenshots/04-tabs.png
- https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/screenshots/06-private.png
- https://raw.githubusercontent.com/technicalnihilist-lgtm/glass-browser-ios/main/screenshots/07-dark.png

## After approval

Once the app is live, Orion's client can generate a developer badge (Developer Mode →
app detail → Developer Deep Links) for the README.
