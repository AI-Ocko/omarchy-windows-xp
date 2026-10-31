#!/usr/bin/env python3
"""tray-art.check.py [--sheet out.png]

Checks Bar.qml's xpTrayArt map the way xpTrayArtUrl() resolves it: every
"<lib>/<id>" entry must exist as a 32 px export (or, marked "@16", as a 16 px
one) under omarchy/xp/assets/graphics, and every "theme:" entry in the
windows-xp-base icon theme. Exits 1 if any is missing. The art is
git-ignored, so run omarchy/xp/fetch-assets.sh first.

--sheet renders each glyph beside the icon it resolves to, at 4x, for eyeballing
identity (CLAUDE.md: presence in the font is not the check, identity is).
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GRAPHICS = os.path.join(HERE, "..", "..", "xp", "assets", "graphics")
THEME = os.path.expanduser("~/.local/share/icons/windows-xp-base")


def entries():
    src = open(os.path.join(HERE, "Bar.qml"), encoding="utf-8").read()
    block = src[src.index("readonly property var xpTrayArt: ({"):]
    block = block[:block.index("})")]
    for m in re.finditer(r'"\\u(?:\{([0-9A-Fa-f]+)\}|([0-9A-Fa-f]{4}))":\s*"([^"]+)"', block):
        yield int(m.group(1) or m.group(2), 16), m.group(3)


def resolve(art):
    if art == "chevron":
        return None
    if art.startswith("theme:"):
        return os.path.join(THEME, art[6:] + ".png")
    size = "32"
    if "@" in art:
        art, size = art.split("@")
    lib, ident = art.split("/", 1)
    return os.path.normpath(os.path.join(GRAPHICS, lib, size, ident + ".png"))


def main():
    rows, missing = [], []
    for cp, art in entries():
        path = resolve(art)
        if path is None:
            continue
        ok = os.path.isfile(path)
        print("%s U+%04X %-24s %s" % ("ok     " if ok else "MISSING", cp, art, path))
        (rows if ok else missing).append((cp, art, path))
    assert rows, "no entries parsed from Bar.qml"
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        font = subprocess.run(["fc-match", "-f", "%{file}", "JetBrainsMono Nerd Font"],
                              capture_output=True, text=True).stdout
        label = subprocess.run(["fc-match", "-f", "%{file}", "Liberation Sans"],
                               capture_output=True, text=True).stdout
        cmd = ["magick"]
        for cp, art, path in rows:
            cmd += ["(", "-size", "96x96", "xc:#d4d0c8", "-font", font, "-pointsize", "60",
                    "-gravity", "center", "-annotate", "+0+0", chr(cp),
                    "(", path, "-filter", "point", "-resize", "96x96", ")", "+append",
                    "(", "-size", "300x96", "xc:#d4d0c8", "-font", label, "-pointsize", "15",
                    "-gravity", "west", "-annotate", "+8+0", "U+%04X  %s" % (cp, art), ")",
                    "+append", ")"]
        cmd += ["-background", "#d4d0c8", "-append", out]
        subprocess.run(cmd, check=True)
        print("sheet:", out)
    if missing:
        sys.exit("%d missing" % len(missing))


if __name__ == "__main__":
    main()
