<div align="center">

# chrome-theme-sync

[![Caelestia KDE](https://img.shields.io/badge/Caelestia_KDE-2.7.6_tested-9bd0cc?style=for-the-badge&labelColor=101418)](https://github.com/caelestia-kde/caelestia)
[![KDE Plasma](https://img.shields.io/badge/Plasma_6-1D99F3?logo=kde&logoColor=white&style=for-the-badge&labelColor=101418)](https://kde.org/plasma-desktop)
[![Version](https://img.shields.io/badge/Version-1.0.0-9bd0cc?style=for-the-badge&labelColor=101418)](metadata.json)
[![License: MIT](https://img.shields.io/badge/License-MIT-9bd0cc?style=for-the-badge&labelColor=101418)](LICENSE)

</div>

> [!NOTE]
> ✅ **Tested and working on Caelestia KDE 2.7.6** (Plasma 6.8.3, Google Chrome 158).

Your browser follows your Caelestia colours. Change the wallpaper or the scheme and Chrome
repaints itself about a second later. No restart, no extension.

Works with Google Chrome, Chromium and Brave, whichever you have.

Why this exists: stock Caelestia's CLI has Chrome theming built in, but Caelestia KDE never
calls it. So Chrome gets stuck on whatever colour it got last time (often a bluish one), and
when the old code does run, a broken `chrome-flags.conf` can make it open a pile of junk tabs.
This plugin does the job properly from the shell.

## Install

Grab the zip from the [latest release](https://github.com/COCONAT10MEN/chrome-theme-sync/releases/latest), unzip it and double-click
**Install** inside. That's it.

Or paste this into Caelestia's *Settings → Plugins*:

```
https://github.com/COCONAT10MEN/chrome-theme-sync
```

The first time it runs it needs your admin password once (a normal password prompt), because
browsers only take theme colours from a system folder. After that it's silent.

If you cancel the prompt, it leaves things alone. Turn the plugin off and on to get asked again.

## Settings

In *Settings → Plugins → Chrome Theme Sync*:

- **Background** (default) matches the desktop: dark, subtle, same tone as your panels.
- **Accent** uses your scheme's main colour instead. Louder, but fun.

## Good to know

- Chrome will say "Your browser is managed by your organization". That's just how Chrome
  labels anything set from the system folder. Nothing else is managed, it's only the colour.
- Light/dark follows your system too.
- While Chrome is themed this way, its own colour picker is locked. Uninstall to get it back.

## Uninstall

Remove it in *Settings → Plugins*, then run this once to take the colour off your browser and
clean up the admin bits:

```bash
sudo sh ~/.config/caelestia/plugins/chrome-theme-sync/helper/setup.sh uninstall
```

(Run it before removing the plugin folder, or grab `helper/setup.sh` from this repo.)

## What it installs

Just two small things outside the plugin folder:

- `/usr/local/libexec/caelestia-chrome-theme`, a tiny script that writes the colour file. It
  only accepts a hex colour, nothing else.
- `/etc/sudoers.d/caelestia-chrome-theme`, which lets your user run that one script without a
  password.

The colour itself goes in `/etc/opt/chrome/policies/managed/caelestia.json` (Chromium and
Brave have their own `/etc/...` folders).

## License

MIT. Free to use, change and share. If you build on it, a credit to
[COCONAT10MEN](https://github.com/COCONAT10MEN) is appreciated.
