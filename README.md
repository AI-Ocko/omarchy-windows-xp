# Windows XP for Omarchy

The Windows XP look for [Omarchy](https://omarchy.org) 4 (Quattro): five
colour schemes (Luna Blue, Olive Green, Silver, Royale, Zune), the taskbar and
Start menu, XP-style tray pop-ups and dialogs, title bars with real XP caption
buttons, cursors, fonts, GTK theme, a cmd.exe terminal, sounds, the 3D Pipes
screensaver and an optional XP boot screen. It changes nothing else about your
desktop, and any non-XP theme puts the stock Omarchy look back.

## Install

From a terminal in your Omarchy session, as yourself (not root):

```sh
./install.sh            # or: ./install.sh --dry-run  to see every step first
```

It asks for sudo once for packages (pacman, then the AUR title-bar plugin via
`yay`), downloads Microsoft's files (below), and ends on
`omarchy theme set windows-xp`. The boot screen is offered last, behind its own
`[y/N]`. Open a new terminal afterwards; reboot once if you took the boot
screen.

Switch schemes like any Omarchy theme: `windows-xp`, `windows-xp-olive`,
`windows-xp-silver`, `windows-xp-royale`, `windows-xp-zune`.

**Update:** `git pull && ./install.sh` (safe to re-run).

**Uninstall:** `./uninstall.sh` switches to Omarchy's default theme, then removes
everything it installed in your account. It prints, rather than runs, the two
sudo commands left: turning the boot screen off and removing the packages.

## What it changes outside its own folders

- `~/.config/foot/foot.ini`, `~/.bashrc`, `~/.config/tmux/tmux.conf`: one marked
  block each (`# >>> omarchy-windows-xp`), with a `.pre-xp` backup.
- `~/.local/share/{fonts/xp,themes/Windows XP *,icons/windows-xp*}`,
  `~/.local/lib/hyprbars-xp`, and a `xp-sizes.path` systemd user unit that
  keeps the XP terminal font in step with `omarchy display text size`.
- Text size is Omarchy's: XP pins no size of its own.

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
- **Hyprland:** the title bars need the AUR `hyprland-plugin-hyprbars` to match
  your Hyprland (0.56.x today). Re-run `~/.config/omarchy/xp/hyprbars/build`
  after a Hyprland update; without a match, windows simply keep their stock
  borders.

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
