# Windows XP for Omarchy

The Windows XP look for [Omarchy](https://omarchy.org) 4 (Quattro): five
colour schemes (Luna Blue, Olive Green, Silver, Royale, Zune), the taskbar and
Start menu, XP-style tray pop-ups and dialogs (with XP's own battery meter),
title bars with real XP caption buttons, the Welcome screen as the lock
screen, cursors, fonts, GTK theme, a cmd.exe terminal, sounds, the 3D Pipes
screensaver and an optional XP boot screen. It changes nothing else about your
desktop, and any non-XP theme puts the stock Omarchy look back.

The cmd.exe palette, in foot, neovim and colors.toml, has its six too-dark colours
raised to 5:1 on black. `xp-nvim-check` fails if any of them, or any nvim highlight
group, drops below the bar again.

## Install

From a terminal in your Omarchy session, as yourself (not root):

```sh
./install.sh            # or: ./install.sh --dry-run  to see every step first
```

It asks for sudo only if a package it needs is missing (pacman; nothing comes
from the AUR), downloads Microsoft's files (below), builds the title-bar plugin
in your account, and ends on `omarchy theme set windows-xp`. Run it from a
terminal: if a package is missing it needs one for the sudo password. The boot screen is offered last, behind its own
`[y/N]`. Open a new terminal afterwards; reboot once if you took the boot
screen.

Switch schemes like any Omarchy theme: `windows-xp`, `windows-xp-olive`,
`windows-xp-silver`, `windows-xp-royale`, `windows-xp-zune`.

**Update:** `git pull && ./install.sh` (safe to re-run).

**Uninstall:** `./uninstall.sh` switches to Omarchy's default theme, then removes
everything it installed in your account. It prints, rather than runs, the two
sudo commands left: turning the boot screen off and removing the packages.

## Browser dark mode

Under every XP scheme, Zen, Chromium and Google Chrome run dark: web pages get
`prefers-color-scheme: dark`, and the browsers' own UI keeps the XP look in a
dark palette (graphite faces from Microsoft's unreleased Royale Noir (its
Start menu and task pane), each scheme's own caption gradient and highlight;
Zune in its own black and orange). The rest of the desktop stays light.

```
~/.config/omarchy/xp/bin/xp-mode browser-dark off      # back to the light XP browsers
~/.config/omarchy/xp/bin/xp-mode browser-dark on       # dark again (the default)
~/.config/omarchy/xp/bin/xp-mode browser-dark status
```

The choice is kept in `~/.config/omarchy/xp/browser-dark` across theme
switches and reboots. Browsers read it when they start: restart Zen, Chromium
and Chrome to see a change (the command says which are running; it never
closes them). Chromium's tab-strip colour follows at once.

## What it changes outside its own folders

- `~/.config/foot/foot.ini`, `~/.bashrc`, `~/.config/tmux/tmux.conf`: one marked
  block each (`# >>> omarchy-windows-xp`), with a `.pre-xp` backup.
- `~/.local/share/{fonts/xp,themes/Windows XP *,icons/windows-xp*}`,
  `~/.local/lib/hyprbars-xp`, and a `xp-sizes.path` systemd user unit that
  keeps the XP terminal font in step with `omarchy display text size`.
- While an XP theme is on, `~/.config/omarchy/shell.json` selects the XP bar
  and the XP versions of the menu, notifications, OSD, idle, polkit and lock
  plugins, and disables the ones they replace, including your own clones of
  them (e.g. a `you.lock` cloned from `omarchy.lock`), so there is only ever
  one lock screen and one polkit agent. Leaving XP puts both lists back
  exactly. The lock is swapped only while unlocked.
- `~/.config/gtk-4.0/gtk.css` (a link, while XP is on); the folder is created
  if it was missing and removed again when XP is turned off.
- Text size is Omarchy's: XP pins no size of its own.
- Browser dark mode (while a XP theme is on and `browser-dark` is on; all
  of it undone when you leave XP or turn it off): a marked
  `--force-dark-mode` block at the end of `~/.config/chromium-flags.conf` and
  `~/.config/chrome-flags.conf` (the untouched file waits in
  `~/.local/state/omarchy/xp/browser-dark/` and is moved back byte for byte),
  the scheme's dark tab-strip colour through Omarchy's own browser-policy
  helper, and two prefs in the Zen `user.js` block below:
  `layout.css.prefers-color-scheme.content-override` (dark pages) and
  `zen.view.window.scheme` (Zen's own window colours).
- Zen's `user.js` (while a XP theme is on, light or dark): a marked block
  (`// >>> omarchy-windows-xp browser-dark`) with
  `toolkit.legacyUserProfileCustomizations.stylesheets`, without which Zen
  ignores the XP `userChrome.css`. The prefs you had before come back when
  XP is turned off. Zen keeps these prefs in `prefs.js` while it runs, so if
  Zen is open when one is dropped, the block turns into a reset and the
  clean-up finishes after Zen is closed (the next `xp-mode` call or your
  next login); `uninstall.sh` asks you to close Zen first in that case.

## Battery

Measured on a laptop with a quad-core Intel i5 and two batteries, on battery, idle desktop,
the same brightness throughout: 30 s to settle, then 3 minutes per theme with
`power_now` sampled every 5 s; CPU is the process's own time over those 3
minutes, as % of one core (Omarchy 4.0.6, Hyprland 0.56.2, 2026-10-31).

| theme | power, average (W) | min-max (W) | quickshell CPU | Hyprland CPU |
|---|---|---|---|---|
| tokyo-night (stock) | 9.77 | 9.16-11.59 | 0.1 % | 0.5 % |
| windows-xp | 9.78 | 9.19-12.87 | 0.1 % | 0.7 % |
| windows-vista (Aero) | 9.37 | 9.15-10.49 | 0.1 % | 0.5 % |
| windows-vista-basic | 9.43 | 9.29-10.05 | 0.0 % | 0.5 % |

The differences are within the noise of one 3-minute run per theme: neither
theme costs measurable battery against stock Omarchy. The Windows Vista
numbers are from the companion omarchy-windows-vista, measured in the same run.

## Microsoft's files are not in this repository

`~/.config/omarchy/xp/fetch-assets.sh` (run by the installer) downloads them on
your machine, for your personal use, into `~/.config/omarchy/xp/assets/`:

- individual files from a Windows XP Professional SP3 CD image on
  **archive.org** (fonts, sounds, bitmaps, cursors, boot screen);
- wallpapers from **upload.wikimedia.org** and **archive.org**, and the Royale
  and Zune theme packages from **archive.org**;
- the B00merang Windows XP GTK and icon themes from **GitHub**.

They are Microsoft's copyrighted originals (and third-party GPL themes), pulled
from third-party archives. Every download is pinned by sha256; a changed file
fails the run instead of being used, and nothing downloaded is ever executed.
None of it is ever committed here.

## Omarchy versions

- **Supported:** Omarchy 4.0.x (Quattro). `VERSION` names the release each XP
  part was last verified against.
- **Always safe:** the XP parts copy Omarchy code, so an update can break one.
  Before enabling them, and after every `omarchy update`, `xp-compat-test`
  checks each against the installed Omarchy; one that no longer fits stays off,
  its stock Omarchy version keeps working, and you get one notification naming
  it. If the taskbar itself fails, you get the stock bar with the rest of XP.
- **Omarchy 5:** a new port, not promised.
- **Hyprland:** the XP title bars are hyprbars with XP's caption buttons,
  built in your account for the exact Hyprland you run (0.56.x today; the
  installer checks the headers match). After a Hyprland update the build
  repeats by itself at your next login (or `omarchy update`, or the next
  switch to an XP theme), in the background; until then windows have plain
  title bars. If a rebuild fails you get one notification and the log is
  `~/.local/state/omarchy/xp/hyprbars-build.log`. By hand:
  `~/.config/omarchy/xp/hyprbars/build && hyprctl reload`. The AUR
  `hyprland-plugin-hyprbars` is not used.

## Boot screen warning

The XP boot screen also draws the disk-encryption password prompt. If it ever
misbehaves at boot, press **Esc** for the plain text prompt (typing the
password blind also works), or pick a Limine **Snapshots** entry, then run
`~/.config/omarchy/xp/bin/xp-boot off`. The installer offers it only when such
a fallback entry exists. Omarchy updates that touch Plymouth can reset it; you
will get a notification saying how to turn it back on.

## Licence

MIT (see `LICENSE`), including code copied from Omarchy (MIT). The caption-
button patch modifies hyprland-plugins (BSD-3-Clause). See `NOTICE.md`.
