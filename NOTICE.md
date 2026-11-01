# Notices

## Omarchy (MIT)

Every `payload/omarchy/plugins/ocko.xp-*` plugin is a modified copy of a stock
Omarchy plugin (named in its `manifest.json` as `omarchy.clonedFrom`; the exact
stock files and their sha256 are in its `compat.json`). The four SVGs in
`ocko.xp-agents/assets/` are Omarchy's. Omarchy's MIT licence is reproduced in
`LICENSE`.

## hyprland-plugins (BSD-3-Clause)

`payload/omarchy/xp/hyprbars/xp-captions.patch` modifies hyprbars from
[hyprwm/hyprland-plugins](https://github.com/hyprwm/hyprland-plugins), which
`hyprbars/build` downloads and patches on your machine. Its licence:

```
BSD 3-Clause License

Copyright (c) 2023, Hypr Development

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## Downloaded, never shipped

`fetch-assets.sh` downloads these on the user's machine; none are in this
repository:

- Microsoft's Windows XP files (fonts, sounds, bitmaps, cursors, wallpapers,
  the Royale and Zune themes): Microsoft's copyright, fetched from third-party
  archives for the user's personal use.
- B00merang-Project [Windows-XP](https://github.com/B00merang-Project/Windows-XP)
  GTK themes (GPL-3.0) and
  [WinXP-Icons](https://github.com/B00merang-Project/WinXP-Icons) (GPL-2.0),
  at pinned commits.

## Browser dark mode palettes

The colour values in `payload/omarchy/themes/*/zen-dark.css` and
`chromium-dark.theme` were sampled (as hex values only) from screenshots of
Microsoft's Royale Noir and Zune visual styles. No screenshot or other
Microsoft file is included in this repository.
