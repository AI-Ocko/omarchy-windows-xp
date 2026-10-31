# Windows XP assets

Microsoft's original Windows XP artwork, fonts and sounds, downloaded **for
personal use on this machine only**. Nothing under `assets/` is tracked or may
be committed. `.gitignore` re-ignores `omarchy/xp/assets/**` after the
`omarchy/xp/**` whitelist. What *is* tracked is the recipe:

```sh
omarchy/xp/fetch-assets.sh     # idempotent; re-run any time
```

It needs `curl cabextract 7z bsdtar python3 fc-cache` and never installs
anything. It downloads into `assets/`, verifies every download **and** every
extracted/derived file against a pinned sha256, and installs the fonts to
`~/.local/share/fonts/xp/` with `fc-cache`. Nothing downloaded is ever run:
archives are unpacked into a fresh empty directory with
cabextract/7z/bsdtar, and PE files (`.exe`/`.dll`/`.msstyles`) are only parsed
for their resource section by a small stdlib-Python reader embedded in the
script. Total size is about 50 MB.

## Where it comes from, and how far to trust it

There is no official download for any of this. The hashes are **trust on first
use**, pinned 2026-10-28. On a mismatch the run fails loudly and the file is
not installed. The provenance for each source:

**The Windows XP Professional SP3 CD**, read member by member from Internet
Archive item
[`en-windows-xp-professional-with-service-pack-3-x-86-1`](https://archive.org/details/en-windows-xp-professional-with-service-pack-3-x-86-1).
IA serves single files out of an ISO, so the 617 MB image is never downloaded.
Throughout this file, "ISO/I386/X" means:

```
https://archive.org/download/en-windows-xp-professional-with-service-pack-3-x-86-1/en_windows_xp_professional_with_service_pack_3_x86%20%281%29.iso/I386/X
```

- IA records the ISO as 617,754,624 bytes, SHA-1
  `66ac289ae27724c5ae17139227cbe78c01eefe40`. I could not find that SHA-1
  published anywhere, so the image itself is **unverified**.
- **Corroboration:** three fonts extracted from it are byte-identical to the
  same fonts from hash-vetted redistributables. These are the winetricks / AUR
  `ttf-ms-fonts` pins, and all three archive hashes matched on download.
  - `trebucit.ttf` and `trebucbi.ttf` match corefonts
    [`trebuc32.exe`](https://downloads.sourceforge.net/project/corefonts/the%20fonts/final/trebuc32.exe)
    (`5a690d9b…`).
  - `lucon.ttf` matches Microsoft's NT4 Euro hotfix
    [`eurofixi.exe`](http://ftpmirror.your.org/pub/misc/ftp.microsoft.com/bussys/winnt/winnt-public/fixes/usa/NT40TSE/hotfixes-postSP3/Euro-fix/eurofixi.exe)
    (`41f272a3…`).
- The ISO's Tahoma is v3.15, the XP version. The redistributable
  [`IELPKTH.CAB`](https://downloads.sourceforge.net/corefonts/OldFiles/IELPKTH.CAB)
  (`c1be3fb8…`) carries IE5.5's older v1.2, which is why it is not used.
- Every member was checked with `file` before pinning: TrueType, RIFF WAVE,
  JPEG, PC bitmap, PE32 and INF, as expected.

**The Royale theme:** Microsoft's 2004 "Royale Theme for Win XP.exe"
installer. It is an InstallShield SFX whose embedded cab cabextract reads
directly. It comes from IA item
[`royale-theme_202607`](https://archive.org/details/royale-theme_202607)
(`Royale_theme.zip`). The zip also holds uploader extras (`bliss.jpg`,
`Bluff.jpg`, not Microsoft's), which are not used.

**The Zune theme:** Microsoft's `ZuneDesktopTheme.msi`. Its MSI summary says
"Author: Microsoft Corporation", created 2006-11-03. It comes from IA item
[`zune-desktop-theme_202109`](https://archive.org/details/zune-desktop-theme_202109).

**High-resolution wallpapers:**
- **Bliss, 4510x3627:** IA [`bliss-600dpi`](https://archive.org/details/bliss-600dpi),
  a 600 dpi scan of Charles O'Rear's original photograph. Side by side it is
  the same frame and colour grade as XP's 800x600 `bliss.jpg`, with more sky
  and field around it. It is a real high-resolution original, not an upscale.
  I rejected Microsoft Design's 2024 "4K Bliss" (4089x2726), which is a new
  render of a different scene. I also rejected IA `winxp-bliss_wp_8k`, an AI
  upscale.
- **Autumn, 4200x2800:** IA [`windows-xp-autumn`](https://archive.org/details/windows-xp-autumn).
  This is Peter Burian's original photo: the same frame as XP's 800x600 crop,
  just wider.

**Reference screenshots:** from Wikipedia and Wikimedia Commons
(`upload.wikimedia.org`). The en.wikipedia ones are non-free fair-use
screenshots, kept here for personal comparison only. Wikimedia rate-limits
bursts (HTTP 429, `Retry-After: 600`), so the script paces those downloads and
retries.

## Derived files (built locally from pinned inputs, then pinned themselves)

- **`graphics/{luna,royale,zune}/`:** the `BITMAP` and `TEXTFILE` resources of
  `luna.msstyles`, `Royale.msstyles` and `Zune.msstyles`.
  - Bitmap prefixes: `BLUE_`, `HOMESTEAD_` (Olive Green), `METALLIC_` (Silver),
    `ROYALE_`, `DEFAULT_` (Zune). There are 186 per scheme, covering the title
    bar, caption buttons, taskbar, start button, Start menu panels, tray,
    scrollbars, buttons and so on.
  - The `TEXTFILE/NORMAL*_INI.bin` files (UTF-16LE) are each scheme's style
    sheet, with sizing margins, image counts, fonts and colours. They are the
    authoritative layout for 9-slice `BorderImage` work.
  - Many bitmaps use magenta `#FF00FF` (or red `#FF0000` where the INI says
    `TransparentColor`) as a transparency key, not alpha.
- **`graphics/ntoskrnl/`:** the kernel's boot bitmaps.
  - `1` is the 640x480 boot screen, `8` the blue progress-bar segment (22x9),
    `4` a grey segment, `3` "It is now safe to turn off your computer."
    (213x11), `2` "Hibernating…", and `5/6/7/13/14/15` the
    server/embedded/header variants.
  - They ship with an **all-zero palette**; XP supplies the palette at boot.
- **`graphics/boot/*.bmp`:** bitmaps 1, 8 and 3 with the boot palette restored.
  - Palette indices 0–14 were recovered by voting every pixel of bitmap 1
    against `reference/boot-screen-xp-professional.png`. Each index agreed 100%
    outside the animated progress area.
  - `boot-screen.bmp` differs from the real capture in 2,185 pixels (0.7%).
    Those are the "Professional" edition text, the "Copyright © 1985-2001"
    line and the moving progress blocks, which XP draws over bitmap 1 at boot.
    They are not in this bitmap.
  - **Index 15 is unknown.** It is the only colour in the "safe to turn off"
    text, and no real capture of that screen was found. It is set to white
    here; see palette.md.
- **`graphics/{explorer,logonui,msgina}/`:**
  - **explorer:** the start-button flag (`143`), pixel-exact Luna taskbar
    previews (`146`–`153`), Start menu previews (`170`, `171`) and
    notification-area previews with the clock (`180`–`183`).
  - **logonui:** the Welcome / "Windows is shutting down" screen pieces, the
    turn-off and log-off icons, and the default chess tile.
  - **msgina:** the "Log On to Windows" banner for each edition (`101` is
    Professional) with its colour strip (`103`), the Turn Off Computer dialog
    background (`20140`/`20142`), the flag (`20141`/`20143`) and the big
    Stand By / Turn Off / Restart buttons (`20150`, 32x32 states).
- **`graphics/{shell32,user32}-ico/` and the icon PNGs (Task 8):**
  - `xptool.py icons` writes each `GROUP_ICON` as a one-image `.ico` per size
    (16/32/48, the deepest colour depth at that size); those trees are pinned.
  - `bin/xp-taskbar-art` derives `graphics/{shell32,user32}/<size>/<id>.png`
    from them (not pinned: ImageMagick's PNG encoder output varies by version).
  - Identities checked on a contact sheet: user32 `101` warning, `102`
    question, `103` error, `104` information; shell32 `4`/`5` folder, `14`
    Internet, `16` My Computer, `20` Programs, `22` settings, `23` Search,
    `24` Help, `25` Run, `28` Turn Off, `36` Control Panel, `45` Log Off key,
    `47` Windows Update, `48` lock, `166`/`167` add/remove programs, `180`
    display, `185` appearance, `194` keys (Run As), `221` Stand By, `269`
    users, `277` Sounds.
  - shell32 `BITMAP 14356` is the Log Off Windows dialog's two buttons
    (Switch User, Log Off; normal / pressed / hot), cut into
    `graphics/taskbar/dlg-{switch,logoff}-{0,1,2}.png`.
- **`binaries/`:** the PE files the above are parsed from. They are kept so a
  re-run can rebuild derived files offline. They are never executed.

## Files

Sizes are pixel dimensions. Hashes are the first 12 hex digits of the full
sha256 pinned in `fetch-assets.sh`. A directory's hash is the sha256 of its
sorted `sha256sum` listing.

### fonts

| File | Size | sha256 | Source |
|---|---|---|---|
| `fonts/framd.ttf` | – | `f103d31608ff…` | `ISO/I386/FRAMD.TT_` via cab (download sha256 `55d0870dcb8c…`) |
| `fonts/framdit.ttf` | – | `02bf3f5c3289…` | `ISO/I386/FRAMDIT.TT_` via cab (download sha256 `dd651316febb…`) |
| `fonts/lucon.ttf` | – | `6ddf64ee896d…` | `ISO/I386/LUCON.TT_` via cab (download sha256 `34e44c83a9c8…`) |
| `fonts/tahoma.ttf` | – | `08f45bf53995…` | `ISO/I386/TAHOMA.TT_` via cab (download sha256 `eb107c36fada…`) |
| `fonts/tahomabd.ttf` | – | `4ba89e145ff3…` | `ISO/I386/TAHOMABD.TT_` via cab (download sha256 `0bf022886a91…`) |
| `fonts/trebuc.ttf` | – | `9cf5777ebf93…` | `ISO/I386/TREBUC.TT_` via cab (download sha256 `3d43f485d6da…`) |
| `fonts/trebucbd.ttf` | – | `73150ef5306b…` | `ISO/I386/TREBUCBD.TT_` via cab (download sha256 `e103880dab3a…`) |
| `fonts/trebucbi.ttf` | – | `c0a6bdf31f9f…` | `ISO/I386/TREBUCBI.TT_` via cab (download sha256 `a5773b9563b0…`) |
| `fonts/trebucit.ttf` | – | `db56fdac7d3b…` | `ISO/I386/TREBUCIT.TT_` via cab (download sha256 `7033830f6ce3…`) |

### sounds

| File | Size | sha256 | Source |
|---|---|---|---|
| `sounds/balloon.wav` | – | `c9de87a87b68…` | `ISO/I386/XPBALLN.WA_` via cab (download sha256 `73d1e7fa864d…`) |
| `sounds/battery-critical.wav` | – | `cb02dd9f8b4d…` | `ISO/I386/XPBATCRT.WA_` via cab (download sha256 `97185c9fd527…`) |
| `sounds/battery-low.wav` | – | `bd4a58b1e2b8…` | `ISO/I386/XPBATLOW.WA_` via cab (download sha256 `3983234a8506…`) |
| `sounds/popup-blocked.wav` | – | `df7cad111688…` | `ISO/I386/XPBLKPOP.WA_` via cab (download sha256 `0efe139beb7c…`) |
| `sounds/critical-stop.wav` | – | `1b86a1b8b7b5…` | `ISO/I386/XPCRTSTP.WA_` via cab (download sha256 `9c5c3500cb7f…`) |
| `sounds/default.wav` | – | `d0426433cb15…` | `ISO/I386/XPDEF.WA_` via cab (download sha256 `97b62dcebdfa…`) |
| `sounds/ding.wav` | – | `20fc59d9f846…` | `ISO/I386/XPDING.WA_` via cab (download sha256 `7f1dfa809120…`) |
| `sounds/error.wav` | – | `4b51ec1b1b14…` | `ISO/I386/XPERROR.WA_` via cab (download sha256 `9c4aec17aa57…`) |
| `sounds/exclamation.wav` | – | `b57b8e8818c4…` | `ISO/I386/XPEXCL.WA_` via cab (download sha256 `5772cfa7b9e3…`) |
| `sounds/hardware-fail.wav` | – | `fe6e852ff646…` | `ISO/I386/XPHDFAIL.WA_` via cab (download sha256 `3f8f2ea5aed5…`) |
| `sounds/hardware-insert.wav` | – | `a3e44db91795…` | `ISO/I386/XPHDINST.WA_` via cab (download sha256 `cb611d2a7297…`) |
| `sounds/hardware-remove.wav` | – | `c4d09c6ad6a9…` | `ISO/I386/XPHDREM.WA_` via cab (download sha256 `138f5aa52206…`) |
| `sounds/information-bar.wav` | – | `b4dfbdfd8d6a…` | `ISO/I386/XPINFBAR.WA_` via cab (download sha256 `7ac61b591352…`) |
| `sounds/logoff.wav` | – | `e0c0e5dea255…` | `ISO/I386/XPLOGOFF.WA_` via cab (download sha256 `205a827e318f…`) |
| `sounds/logon.wav` | – | `8d71fba4267f…` | `ISO/I386/XPLOGON.WA_` via cab (download sha256 `daa11fe25ec2…`) |
| `sounds/menu-command.wav` | – | `da4fc6f8917b…` | `ISO/I386/XPMENU.WA_` via cab (download sha256 `74767cc6f445…`) |
| `sounds/minimize.wav` | – | `974da6baee41…` | `ISO/I386/XPMIN.WA_` via cab (download sha256 `56ae4c4e4dc7…`) |
| `sounds/notify.wav` | – | `760cdd568500…` | `ISO/I386/XPNOTIFY.WA_` via cab (download sha256 `d9c55f3aebb2…`) |
| `sounds/print-complete.wav` | – | `e411c0247187…` | `ISO/I386/XPPRINT.WA_` via cab (download sha256 `abe41dd2e111…`) |
| `sounds/recycle.wav` | – | `a8a7028f9fe9…` | `ISO/I386/XPRECYCL.WA_` via cab (download sha256 `2213c55bf0af…`) |
| `sounds/restore.wav` | – | `480dea5b1808…` | `ISO/I386/XPRESTOR.WA_` via cab (download sha256 `99c2f7bebfe7…`) |
| `sounds/ringin.wav` | – | `b2cd4e4a9776…` | `ISO/I386/XPRINGIN.WA_` via cab (download sha256 `385e7ee7c505…`) |
| `sounds/ringout.wav` | – | `d994081372c2…` | `ISO/I386/XPRNGOUT.WA_` via cab (download sha256 `4c711c4b64cb…`) |
| `sounds/shutdown.wav` | – | `3d937337075a…` | `ISO/I386/XPSHUTDN.WA_` via cab (download sha256 `295cd4b96a3b…`) |
| `sounds/start-navigation.wav` | – | `d5712a8963eb…` | `ISO/I386/XPSTART.WA_` via cab (download sha256 `70958c4c91cf…`) |
| `sounds/startup.wav` | – | `8f859ebb9024…` | `ISO/I386/XPSTARTU.WA_` via cab (download sha256 `1bf5840d2ab0…`) |

### wallpapers

| File | Size | sha256 | Source |
|---|---|---|---|
| `wallpapers/bliss-4510x3627.png` | 4510x3627 | `a72d44ee40c4…` | [bliss-600dpi.png](https://archive.org/download/bliss-600dpi/bliss-600dpi.png) (download sha256 `a72d44ee40c4…`) |
| `wallpapers/autumn-4200x2800.jpg` | 4200x2800 | `3e4be6eaf5f1…` | [CB040538.jpg](https://archive.org/download/windows-xp-autumn/CB040538.jpg) (download sha256 `3e4be6eaf5f1…`) |
| `wallpapers/ascent.jpg` | 800x600 | `6b5e3866752b…` | `ISO/I386/ASCENT.JP_` via cab (download sha256 `79dca4293000…`) |
| `wallpapers/autumn.jpg` | 800x600 | `1d9986cf6f04…` | `ISO/I386/AUTUMN.JP_` via cab (download sha256 `1e6cbd57a9df…`) |
| `wallpapers/azul.jpg` | 800x600 | `73eace3d028b…` | `ISO/I386/AZUL.JP_` via cab (download sha256 `3559aa2647b9…`) |
| `wallpapers/bliss.jpg` | 800x600 | `aecf72dc2cb3…` | `ISO/I386/BLISS.JP_` via cab (download sha256 `4fd6799156da…`) |
| `wallpapers/crystal.jpg` | 800x600 | `8a4aa3b17640…` | `ISO/I386/CRYSTAL.JP_` via cab (download sha256 `ef2a4aa44ebf…`) |
| `wallpapers/follow.jpg` | 800x600 | `50e2837599f6…` | `ISO/I386/FOLLOW.JP_` via cab (download sha256 `094944e3ef44…`) |
| `wallpapers/friend.jpg` | 800x600 | `36cdbf794361…` | `ISO/I386/FRIEND.JP_` via cab (download sha256 `69ffbbd746a3…`) |
| `wallpapers/home.jpg` | 800x600 | `0b337b96eb63…` | `ISO/I386/HOME.JP_` via cab (download sha256 `1cc8c39f15a6…`) |
| `wallpapers/moon-flower.jpg` | 800x600 | `f41d62dcc6b3…` | `ISO/I386/MOON.JP_` via cab (download sha256 `e6238d9cbc90…`) |
| `wallpapers/peace.jpg` | 800x600 | `c52887b2f24d…` | `ISO/I386/PEACE.JP_` via cab (download sha256 `660adc22737a…`) |
| `wallpapers/power.jpg` | 800x600 | `151982effaa8…` | `ISO/I386/POWER.JP_` via cab (download sha256 `aa5046fa81c7…`) |
| `wallpapers/purple-flower.jpg` | 800x600 | `c2dadf25fc5e…` | `ISO/I386/PURPLEF.JP_` via cab (download sha256 `bffd11149ed5…`) |
| `wallpapers/radiance.jpg` | 800x600 | `e5a9b2254e51…` | `ISO/I386/RADIANCE.JP_` via cab (download sha256 `5b22a1f223c7…`) |
| `wallpapers/red-moon-desert.jpg` | 800x600 | `21ca37419999…` | `ISO/I386/REDMOON.JP_` via cab (download sha256 `d1bb59bf9122…`) |
| `wallpapers/ripple.jpg` | 800x600 | `dbc0aa795775…` | `ISO/I386/RIPPLE.JP_` via cab (download sha256 `3c4b02464e97…`) |
| `wallpapers/stonehenge.jpg` | 800x600 | `95d26f5c67a6…` | `ISO/I386/STONEH.JP_` via cab (download sha256 `f2598084b0d7…`) |
| `wallpapers/tulips.jpg` | 800x600 | `9a6924e743e5…` | `ISO/I386/TULIPS.JP_` via cab (download sha256 `5a5ff51291f3…`) |
| `wallpapers/vortec-space.jpg` | 800x600 | `7b4fd2a52b5c…` | `ISO/I386/VORTEC.JP_` via cab (download sha256 `ab954e0ef92b…`) |
| `wallpapers/wind.jpg` | 800x600 | `abf1dae685cd…` | `ISO/I386/WIND.JP_` via cab (download sha256 `699487e1cb2f…`) |
| `wallpapers/windows-xp.jpg` | 800x600 | `b8753e74c04a…` | `ISO/I386/WINXP.JP_` via cab (download sha256 `4f10c044f1e8…`) |

### binaries

| File | Size | sha256 | Source |
|---|---|---|---|
| `binaries/royale-installer.exe` | – | `076fb2f71969…` | [Royale_theme.zip](https://archive.org/download/royale-theme_202607/Royale_theme.zip) via zip member `Royale Theme for Win XP.exe` (download sha256 `5e79f2e40eb8…`) |

### wallpapers

| File | Size | sha256 | Source |
|---|---|---|---|
| `wallpapers/royale-energy-bliss.jpg` | 1024x768 | `7b71bdef2789…` | derived from `binaries/royale-installer.exe` (member `Web/Wallpaper/New Bliss.jpg`) |
| `wallpapers/zune.jpg` | 1024x768 | `da2d9ac5b1f7…` | [ZuneDesktopTheme.msi](https://archive.org/download/zune-desktop-theme_202109/ZuneDesktopTheme.msi) via 7z member `ZuneJPG` (download sha256 `a447ba38983d…`) |
| `wallpapers/zune-widescreen-1900x1200.jpg` | 1900x1200 | `88c1d7a29064…` | [ZuneDesktopTheme.msi](https://archive.org/download/zune-desktop-theme_202109/ZuneDesktopTheme.msi) via 7z member `ZuneWidescreenJPG` (download sha256 `a447ba38983d…`) |

### graphics

| File | Size | sha256 | Source |
|---|---|---|---|
| `graphics/account-pictures/airplane.bmp` | 48x48 | `50bc79f388a6…` | `ISO/I386/AIRPLANE.BM_` via cab (download sha256 `3cb1afd5edf2…`) |
| `graphics/account-pictures/astronaut.bmp` | 48x48 | `5d6f342681f4…` | `ISO/I386/ASTRO.BM_` via cab (download sha256 `3785d026381c…`) |
| `graphics/account-pictures/beach.bmp` | 48x48 | `ba3f69d25e4e…` | `ISO/I386/BEACH.BM_` via cab (download sha256 `2d1967957cc9…`) |
| `graphics/account-pictures/butterfly.bmp` | 48x48 | `e2baa4c727ae…` | `ISO/I386/BUTTERFL.BM_` via cab (download sha256 `418f309993c8…`) |
| `graphics/account-pictures/car.bmp` | 48x48 | `5fc50c87b3f8…` | `ISO/I386/CAR.BM_` via cab (download sha256 `821e11609fc5…`) |
| `graphics/account-pictures/cat.bmp` | 48x48 | `8dd31725432f…` | `ISO/I386/CAT.BM_` via cab (download sha256 `3f8462e2a074…`) |
| `graphics/account-pictures/chess.bmp` | 48x48 | `f5003282e999…` | `ISO/I386/CHESS.BM_` via cab (download sha256 `75ad60e07628…`) |
| `graphics/account-pictures/dirt-bike.bmp` | 48x48 | `dc9657a1a14d…` | `ISO/I386/DIRTBIKE.BM_` via cab (download sha256 `50ee63a8de80…`) |
| `graphics/account-pictures/dog.bmp` | 48x48 | `4cb21f95bccd…` | `ISO/I386/DOG.BM_` via cab (download sha256 `4586bfe4e8aa…`) |
| `graphics/account-pictures/drip.bmp` | 48x48 | `938302353d9e…` | `ISO/I386/DRIP.BM_` via cab (download sha256 `9850bd4491ab…`) |
| `graphics/account-pictures/duck.bmp` | 48x48 | `01d3f4fcf587…` | `ISO/I386/DUCK.BM_` via cab (download sha256 `c6c7c50222f5…`) |
| `graphics/account-pictures/fish.bmp` | 48x48 | `4f5230f4e533…` | `ISO/I386/FISH.BM_` via cab (download sha256 `6ddd5a5fed5d…`) |
| `graphics/account-pictures/frog.bmp` | 48x48 | `075adc45d321…` | `ISO/I386/FROG.BM_` via cab (download sha256 `54b2fb7692c4…`) |
| `graphics/account-pictures/guest.bmp` | 48x48 | `a1030522425b…` | `ISO/I386/GUEST.BM_` via cab (download sha256 `dac5896d8769…`) |
| `graphics/account-pictures/guitar.bmp` | 48x48 | `07d3aeca5d09…` | `ISO/I386/GUITAR.BM_` via cab (download sha256 `cc886b2504ee…`) |
| `graphics/account-pictures/horses.bmp` | 48x48 | `46f556f48406…` | `ISO/I386/HORSES.BM_` via cab (download sha256 `5e90863bbb70…`) |
| `graphics/account-pictures/kick.bmp` | 48x48 | `66e1cd26c61f…` | `ISO/I386/KICK.BM_` via cab (download sha256 `29d5a3c3e85f…`) |
| `graphics/account-pictures/lift-off.bmp` | 48x48 | `66cb10ca453d…` | `ISO/I386/LIFTOFF.BM_` via cab (download sha256 `ae556b75d263…`) |
| `graphics/account-pictures/palm-tree.bmp` | 48x48 | `1d8a8607dd5b…` | `ISO/I386/PALMTREE.BM_` via cab (download sha256 `5d1096a784c5…`) |
| `graphics/account-pictures/pink-flower.bmp` | 48x48 | `38d399a8fac9…` | `ISO/I386/PNKFLOWR.BM_` via cab (download sha256 `9af514967298…`) |
| `graphics/account-pictures/red-flower.bmp` | 48x48 | `4dc0a8afbf4d…` | `ISO/I386/REDFLOWR.BM_` via cab (download sha256 `7d92dbb8ad00…`) |
| `graphics/account-pictures/skater.bmp` | 48x48 | `67a4ceda66f3…` | `ISO/I386/SKATER.BM_` via cab (download sha256 `6284938e92d4…`) |
| `graphics/account-pictures/snowflake.bmp` | 48x48 | `9074d2d9e945…` | `ISO/I386/SNWFLAKE.BM_` via cab (download sha256 `e35550f1809a…`) |
| `graphics/account-pictures/ball.bmp` | 48x48 | `ac791b7dd635…` | `ISO/I386/SOCCER.BM_` via cab (download sha256 `353782532478…`) |

### binaries

| File | Size | sha256 | Source |
|---|---|---|---|
| `binaries/luna.msstyles` | – | `dd8e86e5a7c1…` | `ISO/I386/LUNA.MS_` via cab (download sha256 `a98d8161df17…`) |
| `binaries/ntoskrnl.exe` | – | `6005a1a1db35…` | `ISO/I386/NTOSKRNL.EX_` via cab (download sha256 `fc84d920bb12…`) |
| `binaries/explorer.exe` | – | `1e675cb7df21…` | `ISO/I386/EXPLORER.EX_` via cab (download sha256 `6a7b829988e5…`) |
| `binaries/logonui.exe` | – | `032b6d1f541f…` | `ISO/I386/LOGONUI.EX_` via cab (download sha256 `8d06161915c0…`) |
| `binaries/msgina.dll` | – | `651b16027b4f…` | `ISO/I386/MSGINA.DL_` via cab (download sha256 `d7616b234e7f…`) |
| `binaries/shell32.dll` | – | `7c201e812138…` | `ISO/I386/SHELL32.DL_` via cab (download sha256 `ad0c40de296b…`) |
| `binaries/user32.dll` | – | `acd0ae7b4d5f…` | `ISO/I386/USER32.DL_` via cab (download sha256 `a9e1eec98d0b…`) |
| `binaries/stobject.dll` | – | `670006280ca9…` | `ISO/I386/STOBJECT.DL_` via cab (download sha256 `fe673eb3774f…`) |
| `binaries/netshell.dll` | – | `3c0bfa381cbc…` | `ISO/I386/NETSHELL.DL_` via cab (download sha256 `18f546092e7c…`) |
| `binaries/wuauclt.exe` | – | `20524aa4a86a…` | `ISO/I386/WUAUCLT.EX_` via cab (download sha256 `e98fbeec7d17…`) |
| `binaries/mmsys.cpl` | – | `bb9b488afc5e…` | `ISO/I386/MMSYS.CP_` via cab (download sha256 `aef3f77813c1…`) |
| `binaries/desk.cpl` | – | `1fb5abae6910…` | `ISO/I386/DESK.CP_` via cab (download sha256 `a03edfbb41b1…`) |
| `binaries/powercfg.cpl` | – | `047cfe207d03…` | `ISO/I386/POWERCFG.CP_` via cab (download sha256 `d4b1e1552e4a…`) |
| `binaries/agentsvr.exe` | – | `7a8fa00e694d…` | `ISO/I386/AGENTSVR.EX_` via cab (download sha256 `f60907c100ef…`) |
| `binaries/fsquirt.exe` | – | `8f7e68ae96c3…` | `ISO/I386/FSQUIRT.EX_` via cab (download sha256 `2c0606dc2c78…`) |
| `binaries/xpsp2res.dll` | – | `dea7c556ba9c…` | `ISO/I386/XPSP2RES.DL_` via cab (download sha256 `4a1abe0a5d7f…`); SP2's resources: Bluetooth Devices dialogs 107/132/Options, wireless dialogs |
| `binaries/themeui.dll` | – | `f377590227e3…` | `ISO/I386/THEMEUI.DL_` via cab (download sha256 `91a41e8d5d05…`); Display Properties templates (Settings 1007/1014) |
| `binaries/timedate.cpl` | – | `ca5d2f901583…` | `ISO/I386/TIMEDATE.CP_` via cab (download sha256 `3754842f94f4…`) |
| `binaries/sndvol32.exe` | – | `760fbbecef10…` | `ISO/I386/SNDVOL32.EX_` via cab (download sha256 `2ce9c878d2ab…`) |
| `binaries/input.dll` | – | `79a2b99effcb…` | `ISO/I386/INPUT.DL_` via cab (download sha256 `2d04c0c37aed…`) |
| `binaries/msctf.dll` | – | `2e7a7c08b56e…` | `ISO/I386/MSCTF.DL_` via cab (download sha256 `5d0ee7f29363…`) |
| `binaries/royale.msstyles` | – | `36779612b739…` | derived from `binaries/royale-installer.exe` (member `Resources/Themes/Royale/Royale.msstyles`) |
| `binaries/zune.msstyles` | – | `c95af747cc1b…` | [ZuneDesktopTheme.msi](https://archive.org/download/zune-desktop-theme_202109/ZuneDesktopTheme.msi) via 7z member `ZuneMSSTYLES` (download sha256 `a447ba38983d…`) |

### graphics

| File | Size | sha256 | Source |
|---|---|---|---|
| `graphics/luna`/ | – | `968a16dd9ab6…` | PE resources (`BITMAP,TEXTFILE`) parsed out of `binaries/luna.msstyles` |
| `graphics/royale`/ | – | `27f99dcc4662…` | PE resources (`BITMAP,TEXTFILE`) parsed out of `binaries/royale.msstyles` |
| `graphics/zune`/ | – | `b0086fa438c6…` | PE resources (`BITMAP,TEXTFILE`) parsed out of `binaries/zune.msstyles` |
| `graphics/ntoskrnl`/ | – | `3e2b0fdd4da6…` | PE resources (`BITMAP`) parsed out of `binaries/ntoskrnl.exe` |
| `graphics/explorer`/ | – | `91b9af5a448b…` | PE resources (`BITMAP`) parsed out of `binaries/explorer.exe` |
| `graphics/logonui`/ | – | `134b298c0d75…` | PE resources (`BITMAP`) parsed out of `binaries/logonui.exe` |
| `graphics/msgina`/ | – | `cc31359b2187…` | PE resources (`BITMAP`) parsed out of `binaries/msgina.dll` |
| `graphics/shell32-bmp`/ | – | `643f317d71a6…` | PE resources (`BITMAP`) parsed out of `binaries/shell32.dll` |
| `graphics/timedate-bmp`/ | – | `96d3598bccbf…` | PE resources (`BITMAP`) parsed out of `binaries/timedate.cpl`: 50, the Time Zone tab's world map |
| `graphics/themeui-bmp`/ | – | `7d47377c058e…` | PE resources (`BITMAP`) parsed out of `binaries/themeui.dll`: 126, the Display Properties Settings tab's monitor |
| `graphics/shell32-ico`/ | – | `7c7698d32824…` | every `GROUP_ICON` of `binaries/shell32.dll` as one-image `.ico` at 16/32/48 px (deepest colour depth), `<size>/<id>.ico` |
| `graphics/user32-ico`/ | – | `4ac8bbda8868…` | the same for `binaries/user32.dll` (the message-box icons) |
| `graphics/stobject-ico`/ | – | `369261852d99…` | the same for `binaries/stobject.dll`: XP's systray icons (volume 230, muted 231, AC power 200, safely remove 210) |
| `graphics/netshell-ico`/ | – | `58766159d73e…` | the same for `binaries/netshell.dll`: network connection tray icons (LAN 190–193, disconnected 195, limited 196) |
| `graphics/wuauclt-ico`/ | – | `c8e734603268…` | the same for `binaries/wuauclt.exe`: the Automatic Updates tray icon |
| `graphics/mmsys-ico`/ | – | `ecf75c3b04db…` | the same for `binaries/mmsys.cpl` (microphone 4380) |
| `graphics/desk-ico`/ | – | `072e3d0ea00f…` | the same for `binaries/desk.cpl` (display) |
| `graphics/powercfg-ico`/ | – | `9ae8701bcaaf…` | the same for `binaries/powercfg.cpl` (Power Options: monitor-with-moon 203 (nightlight), AC plug 200 (stay-awake)) |
| `graphics/agentsvr-ico`/ | – | `00e1d87fdbe9…` | the same for `binaries/agentsvr.exe` (Microsoft Agent 113 (agents)) |
| `graphics/fsquirt-ico`/ | – | `2616948dacd0…` | the same for `binaries/fsquirt.exe` (Bluetooth File Transfer: XP SP2's Bluetooth icon 107) |
| `graphics/xpsp2res-ico`/ | – | `f1a291acb2fb…` | the same for `binaries/xpsp2res.dll` (SP2's Bluetooth and wireless icons) |
| `graphics/timedate-ico`/ | – | `0b043ab1d98e…` | the same for `binaries/timedate.cpl` (Date and Time 200 (Date and Time Properties caption)) |
| `graphics/sndvol32-ico`/ | – | `c69a562947b8…` | the same for `binaries/sndvol32.exe` (Volume Control 300-304 (mixer caption, speaker, muted)) |
| `graphics/input-ico`/ | – | `65ff25c7d0b5…` | the same for `binaries/input.dll` (Text Services and Input Languages 200) |
| `graphics/msctf-ico`/ | – | `78787fd8a939…` | the same for `binaries/msctf.dll` (language bar icons) |
| `graphics/boot/boot-screen.bmp` | 640x480 | `0dd5789a62c4…` | ntoskrnl BITMAP 1 + recovered boot palette |
| `graphics/boot/progress-segment.bmp` | 22x9 | `f8f9a140d562…` | ntoskrnl BITMAP 8 + recovered boot palette |
| `graphics/boot/safe-to-turn-off-text.bmp` | 213x11 | `f244c0db682a…` | ntoskrnl BITMAP 3 + recovered boot palette |

### reference

| File | Size | sha256 | Source |
|---|---|---|---|
| `reference/boot-screen-xp-professional.png` | 640x480 | `6fb6c4cc953f…` | [Windows_XP_Professional_boot.png](https://upload.wikimedia.org/wikipedia/commons/8/8a/Windows_XP_Professional_boot.png) (download sha256 `6fb6c4cc953f…`) |
| `reference/logon-welcome-to-windows-dialog.png` | 299x157 | `cd049bfeb497…` | [XP_login.png](https://upload.wikimedia.org/wikipedia/en/5/57/XP_login.png) (download sha256 `cd049bfeb497…`) |
| `reference/desktop-luna-blue.png` | 640x480 | `55c204cee4bd…` | [Windows_XP_Luna.png](https://upload.wikimedia.org/wikipedia/en/6/64/Windows_XP_Luna.png) (download sha256 `55c204cee4bd…`) |
| `reference/desktop-olive-green.png` | 640x480 | `fdbce99dd98e…` | [Windows_XP_Olive_Green.png](https://upload.wikimedia.org/wikipedia/en/3/3a/Windows_XP_Olive_Green.png) (download sha256 `fdbce99dd98e…`) |
| `reference/desktop-silver.png` | 640x480 | `4373a4ea6cf3…` | [Windows_XP_Silver.png](https://upload.wikimedia.org/wikipedia/en/1/1c/Windows_XP_Silver.png) (download sha256 `4373a4ea6cf3…`) |
| `reference/desktop-royale.png` | 640x480 | `870d5cda5164…` | [Windows_XP_Royale.png](https://upload.wikimedia.org/wikipedia/en/4/47/Windows_XP_Royale.png) (download sha256 `870d5cda5164…`) |
| `reference/desktop-zune.png` | 640x480 | `134109839b2d…` | [Windows_XP_Zune.png](https://upload.wikimedia.org/wikipedia/en/3/38/Windows_XP_Zune.png) (download sha256 `134109839b2d…`) |
| `reference/desktop-royale-media-center.png` | 640x480 | `6ba7ab9b5cd0…` | [Windows_XP_Media_Center_desktop.png](https://upload.wikimedia.org/wikipedia/en/5/56/Windows_XP_Media_Center_desktop.png) (download sha256 `6ba7ab9b5cd0…`) |
| `reference/taskbar-luna-blue-1920x974.png` | 1920x974 | `4b87922d3f7c…` | [Windows_XP_x64_screenshot_%28blue_theme%29.png](https://upload.wikimedia.org/wikipedia/commons/f/f1/Windows_XP_x64_screenshot_%28blue_theme%29.png) (download sha256 `4b87922d3f7c…`) |
| `reference/taskbar-olive-green-1920x974.png` | 1920x974 | `8c61216858e6…` | [Windows_XP_x64_screenshot_%28olive_green_theme%29.png](https://upload.wikimedia.org/wikipedia/commons/6/68/Windows_XP_x64_screenshot_%28olive_green_theme%29.png) (download sha256 `8c61216858e6…`) |
| `reference/taskbar-silver-1920x974.png` | 1920x974 | `dec835bb78a9…` | [Windows_XP_x64_screenshot_%28silver_theme%29.png](https://upload.wikimedia.org/wikipedia/commons/0/09/Windows_XP_x64_screenshot_%28silver_theme%29.png) (download sha256 `dec835bb78a9…`) |
| `reference/start-menu-luna-blue.png` | 282x354 | `3d68ed49a9d2…` | [Windows_XP_Start_menu.png](https://upload.wikimedia.org/wikipedia/en/e/ef/Windows_XP_Start_menu.png) (download sha256 `3d68ed49a9d2…`) |
| `reference/start-menu-royale.png` | 282x355 | `e950aaa21720…` | [RoyaleXP2.PNG](https://upload.wikimedia.org/wikipedia/en/a/a5/RoyaleXP2.PNG) (download sha256 `e950aaa21720…`) |
| `reference/taskbar-grouping-luna-blue.png` | 800x24 | `ca1ba795898d…` | [Windows_XP_task_grouping_%28Luna%29.png](https://upload.wikimedia.org/wikipedia/en/7/71/Windows_XP_task_grouping_%28Luna%29.png) (download sha256 `ca1ba795898d…`) |
| `reference/turn-off-computer-dialog.png` | 398x198 | `0200c1fc660f…` | [Windows_XP_Shutdown.png](https://upload.wikimedia.org/wikipedia/en/5/5e/Windows_XP_Shutdown.png) (download sha256 `0200c1fc660f…`) |
| `reference/cmd-exe-ipconfig.png` | 426x234 | `cb8b85906332…` | [Ipconfig_win_xp.png](https://upload.wikimedia.org/wikipedia/en/6/6c/Ipconfig_win_xp.png) (download sha256 `cb8b85906332…`) |
| `reference/cmd-exe-banner.png` | 668x331 | `b37068ef0c4f…` | [Command_Prompt_on_Windows_XP_%28Czech%29.png](https://upload.wikimedia.org/wikipedia/commons/3/36/Command_Prompt_on_Windows_XP_%28Czech%29.png) (download sha256 `b37068ef0c4f…`) |
| `reference/task-manager.png` | 298x333 | `12c9fcf30809…` | [System_idle_process.png](https://upload.wikimedia.org/wikipedia/en/6/6b/System_idle_process.png) (download sha256 `12c9fcf30809…`) |
| `reference/hivedef.inf` | – | `00efcf4da1f5…` | `ISO/I386/HIVEDEF.INF` (download sha256 `00efcf4da1f5…`) |
| `reference/dialog-automatic-updates.png` | 428x139 | `53b5835d3d27…` | [Winautoupdates.PNG](https://upload.wikimedia.org/wikipedia/en/2/2b/Winautoupdates.PNG) (download sha256 `53b5835d3d27…`) |
| `reference/search-companion.png` | 305x240 | `3db280beb3f2…` | [Windows_Explorer_search_puppy.png](https://upload.wikimedia.org/wikipedia/en/9/90/Windows_Explorer_search_puppy.png) (download sha256 `3db280beb3f2…`) |
| `reference/explorer-task-pane.png` | 300x225 | `a21830d48ffd…` | [Windows_Explorer_XP.png](https://upload.wikimedia.org/wikipedia/en/c/c0/Windows_Explorer_XP.png) (download sha256 `a21830d48ffd…`) |

### What each reference shows

| File | Surface |
|---|---|
| `boot-screen-xp-professional.png` | Real XP Professional boot screen, 640x480, 16 colours: the exact boot palette |
| `logon-welcome-to-windows-dialog.png` | Classic logon "Welcome to Windows / Press Ctrl-Alt-Delete" dialog, the same banner and frame as "Log On to Windows" |
| `desktop-{luna-blue,olive-green,silver,royale,zune}.png` | Desktop + taskbar + open Start menu + an inactive My Computer window in each scheme. These are downscaled 640x480 captures, so 1 px features are blurred. Title bars: the window caption at about x 280–630, y 113–126 (inactive) |
| `desktop-royale-media-center.png` | Royale on XP Media Center Edition, with an About Windows dialog (caption rows about y 11–22 at x 560). Its ramp is Royale's *inactive* caption, so no 1:1 active Royale or Zune caption capture exists; use the msstyles bitmaps |
| `taskbar-{luna-blue,olive-green,silver}-1920x974.png` | XP x64 desktops at **1:1**. The taskbar is rows 944–973, the tray from x≈1850. Pixel-exact |
| `start-menu-luna-blue.png`, `start-menu-royale.png` | Start menu, 1:1 |
| `taskbar-grouping-luna-blue.png` | Taskbar with grouped buttons, 1:1 |
| `turn-off-computer-dialog.png` | "Turn off computer" (Hibernate / Stand By / Turn Off / Restart) |
| `cmd-exe-ipconfig.png`, `cmd-exe-banner.png` | cmd.exe window. The second shows the "Microsoft Windows XP [Verze 5.1.2600]" banner and prompt (Czech locale) |
| `task-manager.png` | Task Manager, Processes tab |
| `hivedef.inf` | XP's default-registry INF: source of the system colours that msstyles don't set (tooltip `InfoWindow`) |
| `dialog-automatic-updates.png` | A 1:1 Luna dialog (Automatic Updates): caption, 3 px fixed frame, disabled close, push buttons. The yardstick for `qml/XpWindow` / `XpButton` |
| `search-companion.png` | Search Companion's balloon panel and links (downscaled, cropped) |
| `explorer-task-pane.png` | An Explorer window with the blue task pane and its groups (downscaled); the Control Panel layout |

## Not found / not included

- **High-resolution originals of the other 18 stock wallpapers.** Only XP's own
  800x600 files exist from a trustworthy source. The IA "HD packs" are upscales.
  Royale's wallpaper is Microsoft's 1024x768. Zune ships 1024x768 and
  1900x1200.
- **Reference screenshots of real XP**, none found at a trustworthy, stable
  URL, for:
  - the "Log On to Windows" dialog itself (the "Welcome to Windows" dialog and
    msgina's banner art stand in)
  - All Programs open
  - the Log Off Windows dialog
  - a balloon tip
  - Control Panel in category view, the Run As dialog, the tray volume
    popup, Search Results (Task 8; Wikipedia's category has only the three
    nearby captures listed above)
  - the Run dialog (Commons' `Run_command.png` is GNOME, and en.wikipedia's
    `Run_Windows.png` is Windows 11; both rejected)
  - the "Windows is shutting down" screen
  - a capture of "It is now safe to turn off your computer"
  - 3D Pipes (IA `3d-pipes` shows a monochrome re-render, not XP's; rejected)
  - 1:1 desktops for Royale and Zune (only the downscaled 640x480 ones)
  - BetaWiki has most of these, but its bot protection refuses scripted
    downloads, and working around that is not acceptable. A person could save
    them by hand from a browser into `assets/reference/`.
- **The boot palette's index 15** (the colour of the "safe to turn off" text);
  see above.
- **The boot screen's "Professional" edition text.** It is not in ntoskrnl's
  bitmap 1; crop it from `reference/boot-screen-xp-professional.png` if needed.
- **Royale Noir and Embedded** visual styles (optional extras; IA
  `xp-themes_202008` has them). They are not fetched yet.
- **Icons and cursors** are covered by Task 9; see *GTK, icon and cursor themes* below.
- **XP's animated cursors** (`HOURGLAS.ANI` and friends of the "Windows
  Animated" scheme) are not used: XP's *default* scheme is user32.dll's static
  set, which is what is converted.
- **Hardware-fail and other extra sounds** *are* included beyond the requested
  list: logon, default beep, information bar, pop-up blocked, menu command,
  minimise, restore, print complete, ring in/out, start navigation and
  battery critical.

## GTK, icon and cursor themes (Task 9)

Installed user-level by `fetch-assets.sh` (copied out of `assets/`, a
`.xp-src` stamp holding the pinned tree hash makes reruns no-ops). Not
switched by `omarchy theme set` itself: `xp-mode` selects them, and they stay
installed (unused) under every other theme, like the fonts.

| Installed as | Pinned tree | Source |
|---|---|---|
| `~/.local/share/themes/Windows XP {Luna,Homestead,Metallic,Royale,Zune}` | `gtk/Windows XP *` (5 tree hashes in `fetch-assets.sh`) | B00merang-Project [Windows-XP](https://github.com/B00merang-Project/Windows-XP) at commit `7637830906823af40a3cd7e7079be753d8b7d679` (2025-01-23), GPL-3.0, [codeload tarball](https://codeload.github.com/B00merang-Project/Windows-XP/tar.gz/7637830906823af40a3cd7e7079be753d8b7d679) sha256 `d1b23679eb66…`. The same repo the AUR `windows-xp-themes-git` builds from HEAD. Each has gtk-2.0, gtk-3.0, gtk-3.20 and gtk-4.0. |
| `~/.local/share/icons/windows-xp-base` | `icons/windows-xp-base` `34953c07cf26…` | B00merang-Project [WinXP-Icons](https://github.com/B00merang-Project/WinXP-Icons) (formerly B00merang-Artwork/Windows-XP) at `24e95ad2b12c55dd11883ee7066525527d944039` (2025-11-06), GPL-2.0, [tarball](https://codeload.github.com/B00merang-Project/WinXP-Icons/tar.gz/24e95ad2b12c55dd11883ee7066525527d944039) sha256 `aeed64f644ba…`. What AUR `windows-xp-icons-git` and `windows-xp-icon-theme` package. A YlmfOS remake, not Microsoft's pixels. Its shipped `.icon-theme.cache` is stale and `gtk-update-icon-cache` rejects the tree ("generated cache was invalid"), so the installed copy has no cache. |
| `~/.local/share/icons/windows-xp` | built each run, not pinned | the theme `icons.theme` names: **XP's own** shell32/user32 icons (16/32/48 px PNGs from `xp-taskbar-art`) for folder, user-home/documents, pictures, music, videos, desktop, trash, network, computer, drives, printer, search, run, shutdown, log off, lock, help, web-browser, preferences-system, text and generic files, and the four dialog icons; `Inherits=windows-xp-base,Adwaita,hicolor`. Map: `XP_ICONS` in `fetch-assets.sh`. |
| `~/.local/share/icons/windows-xp-cursors` | `icons/windows-xp-cursors` `cc0e8343dea9…` | `xptool.py xcursor` over `binaries/user32.dll`: XP's "Windows Default" scheme (GROUP_CURSOR 100–114, 32654; ids identified on a contact sheet), 32x32 1bpp, converted to Xcursor at nominal 24 (XP's own pixels) and 48 (2x nearest). XP's cursor drop shadow is added (offset 2,2, 3x3 blur, alpha ≤ 0x50); the I-beam and crosshair are screen-inverting in XP, which Xcursor cannot do, so they are black with a white rim. `Inherits=Adwaita` for shapes XP had none of (grab, zoom, copy, alias, cell, context-menu, vertical-text). |

`assets/branding/{about.txt,screensaver.txt}` are rendered each run from
`graphics/boot/boot-screen.bmp` (crop 256x156+204+118: flag and wordmark) by
`xptool.py halfblock`: truecolor U+2580 half-blocks, 64 columns, for
fastfetch, and a 72-column mono version for the stock ttfx screensaver.
Derived from Microsoft's bitmap, so they stay in `assets/`.

**Uninstall** (after `omarchy theme set <non-XP theme>`, which already stops
using them):

```sh
rm -rf ~/.local/share/themes/'Windows XP '{Luna,Homestead,Metallic,Royale,Zune} \
       ~/.local/share/icons/windows-xp ~/.local/share/icons/windows-xp-base \
       ~/.local/share/icons/windows-xp-cursors
```

## Re-pinning

If a source legitimately changes, the run fails with
`HASH MISMATCH <name>: expected <old> got <new>`. Check the new file with
`file` and by eye, then replace the hash in `fetch-assets.sh`. Never re-pin
blindly.
