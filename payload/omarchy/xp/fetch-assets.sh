#!/usr/bin/env bash
# fetch-assets.sh — download Microsoft's original Windows XP assets (wallpapers,
# fonts, sounds, boot/logon/shell artwork, visual-style bitmaps) plus reference
# screenshots of real XP, for personal use on this machine only.
#
#   omarchy/xp/fetch-assets.sh
#
# Everything lands in omarchy/xp/assets/ (git-ignored; never commit it) and the
# fonts are installed to ~/.local/share/fonts/xp/. User-level only, no sudo.
#
# Trust model: there is no official source for most of this, so every download
# and every derived file is pinned by sha256 (trust-on-first-use, pinned
# 2026-10-28; see ASSETS.md for provenance and cross-checks). A mismatch is
# fatal for that file and the run exits non-zero. Downloads are treated as
# data: archives are unpacked into a fresh empty directory with cabextract /
# 7z / bsdtar, PE files are only *parsed* for their resources, and nothing
# downloaded is ever executed. Idempotent: files already present with the
# right hash are not downloaded again.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ASSETS=$HERE/assets
FONTDIR=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/xp
UA='ocko-omarchy-xp-fetch/1.0 (personal use)'
ISO='https://archive.org/download/en-windows-xp-professional-with-service-pack-3-x-86-1/en_windows_xp_professional_with_service_pack_3_x86%20%281%29.iso/I386'

# ── Tools: never installed from here; listed for the root script instead ──────
missing=()
for t in curl sha256sum cabextract 7z bsdtar python3 fc-cache cmp diff realpath; do
    command -v "$t" >/dev/null || missing+=("$t")
done
if ((${#missing[@]})); then
    echo "fetch-assets: missing tools: ${missing[*]}" >&2
    echo "  (pacman: curl coreutils cabextract 7zip libarchive python fontconfig diffutils) — add to the root script, then re-run." >&2
    exit 2
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/xp-fetch.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src"

# Resource parser, kept outside every extraction directory and run with -I.
cat >"$WORK/xptool.py" <<'PY'
"""xptool.py peres <pe> <outdir> <TYPE,...|*>   dump PE resources (BITMAP -> .bmp)
   xptool.py icons <pe> <outdir> <size,...>      GROUP_ICON -> <outdir>/<size>/<id>.ico
                                                 (one image per file: the deepest
                                                 colour depth at exactly that size)
   xptool.py bootpal <in.bmp> <out.bmp>          give an ntoskrnl boot bitmap its palette
   xptool.py xcursor <user32.dll> <outdir>       XP's standard cursors as an Xcursor theme
   xptool.py halfblock <in.ppm> <out.txt> color|mono  image as U+2580 terminal art
   xptool.py strip <pe> <outdir> <id>:<w>:<rrggbb>  BITMAP <id>, a strip of <w>-px
                                                 frames, as <outdir>/<h>/<n>.png with
                                                 colour <rrggbb> transparent
Parses bytes only; never loads or runs the PE."""
import os, struct, sys

RT = {1: "CURSOR", 2: "BITMAP", 3: "ICON", 4: "MENU", 5: "DIALOG", 6: "STRING", 10: "RCDATA",
      12: "GROUP_CURSOR", 14: "GROUP_ICON", 16: "VERSION", 24: "MANIFEST"}

def resources(path, want):
    """Yield (type label, resource name, raw bytes), first language only."""
    d = open(path, "rb").read()
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    if d[:2] != b"MZ" or d[pe:pe + 4] != b"PE\0\0":
        sys.exit("not a PE file: " + path)
    nsec, = struct.unpack_from("<H", d, pe + 6)
    optsz, = struct.unpack_from("<H", d, pe + 20)
    opt = pe + 24
    magic, = struct.unpack_from("<H", d, opt)
    rsrc_rva, = struct.unpack_from("<I", d, opt + (96 if magic == 0x10B else 112) + 16)
    secs = [struct.unpack_from("<IIII", d, opt + optsz + 40 * i + 8) for i in range(nsec)]

    def off(rva):
        for vsz, va, rsz, rp in secs:
            if va <= rva < va + max(vsz, rsz):
                return rva - va + rp
        raise ValueError("rva %x unmapped" % rva)

    base = off(rsrc_rva)

    def entries(p):
        named, ids = struct.unpack_from("<HH", d, p + 12)
        for i in range(named + ids):
            n, o = struct.unpack_from("<II", d, p + 16 + 8 * i)
            if n & 0x80000000:
                q = base + (n & 0x7FFFFFFF)
                n = d[q + 2:q + 2 + 2 * struct.unpack_from("<H", d, q)[0]].decode("utf-16le")
            yield n, base + (o & 0x7FFFFFFF)

    for tname, tp in entries(base):
        label = RT.get(tname, str(tname)) if isinstance(tname, int) else tname
        if "*" not in want and label not in want:
            continue
        for rname, rp in entries(tp):
            _lang, lp = next(entries(rp))  # first language only
            rva, size = struct.unpack_from("<II", d, lp)
            yield label, rname, d[off(rva):off(rva) + size]

def peres(path, out, want):
    for label, rname, blob in resources(path, want):
        os.makedirs(os.path.join(out, label), exist_ok=True)
        name = str(rname).replace("/", "_")
        if label == "BITMAP":
            hsz, = struct.unpack_from("<I", blob, 0)
            bpp, comp, = struct.unpack_from("<HI", blob, 14)
            ncol = (struct.unpack_from("<I", blob, 32)[0] if hsz >= 36 else 0) or (1 << bpp if bpp <= 8 else 0)
            bits = 14 + hsz + (12 if comp == 3 and hsz == 40 else 0) + 4 * ncol
            blob = b"BM" + struct.pack("<IHHI", 14 + len(blob), 0, 0, bits) + blob
            name += ".bmp"
        else:
            name += ".bin"
        with open(os.path.join(out, label, name), "wb") as f:
            f.write(blob)

def icons(path, out, sizes):
    images, groups = {}, []
    for label, rname, blob in resources(path, {"ICON", "GROUP_ICON"}):
        if label == "ICON":
            images[rname] = blob
        else:
            groups.append((rname, blob))
    for gname, g in groups:
        _res, _typ, count = struct.unpack_from("<HHH", g, 0)
        best = {}
        for i in range(count):
            w, h, ncol, _r, planes, bpp, nbytes, nid = struct.unpack_from("<BBBBHHIH", g, 6 + 14 * i)
            w = w or 256
            if w in sizes and h in (w, 0) and nid in images and bpp >= best.get(w, (0,))[0]:
                best[w] = (bpp, struct.pack("<BBBBHHI", w % 256, h % 256, ncol, 0, planes, bpp, len(images[nid])) , images[nid])
        for w, (_bpp, entry, data) in best.items():
            os.makedirs(os.path.join(out, str(w)), exist_ok=True)
            with open(os.path.join(out, str(w), "%s.ico" % str(gname).replace("/", "_")), "wb") as f:
                f.write(struct.pack("<HHH", 0, 1, 1) + entry + struct.pack("<I", 22) + data)

# XP's boot bitmaps ship with an all-zero palette; the kernel supplies the real
# one at boot. Indices 0-14 were recovered by voting every pixel of
# ntoskrnl BITMAP 1 against a real XP Professional boot capture
# (reference/boot-screen-xp-professional.png): every index agreed 100% except
# where the progress bar is animated. Index 15 is unused by the boot screen and
# the progress segment, so it is unrecoverable from that capture; it is set to
# white here. See palette.md.
BOOT = ["000000", "000000", "404040", "2838c7", "4f5f00", "a83007", "777777", "808800",
        "5878ef", "e8671f", "879ff0", "87d000", "e7b018", "b0b0b0", "efefef", "ffffff"]

def bootpal(src, dst):
    b = bytearray(open(src, "rb").read())
    hsz, = struct.unpack_from("<I", b, 14)
    for i, c in enumerate(BOOT):
        r, g, bl = bytes.fromhex(c)
        b[14 + hsz + 4 * i:18 + hsz + 4 * i] = bytes([bl, g, r, 0])
    open(dst, "wb").write(b)

# XP's "Windows Default" cursor scheme lives in user32.dll as 32x32 1bpp
# GROUP_CURSORs (4bpp for the CD one, unused). Ids identified on a contact
# sheet; the first name of each entry is the file, the rest are symlinks.
XCURSORS = {
    100: "default left_ptr arrow top_left_arrow left-arrow",
    101: "text xterm ibeam",
    102: "wait watch",
    103: "crosshair cross tcross",
    104: "up-arrow center_ptr sb_up_arrow",
    105: "nwse-resize nw-resize se-resize size_fdiag bd_double_arrow top_left_corner bottom_right_corner",
    106: "nesw-resize ne-resize sw-resize size_bdiag fd_double_arrow top_right_corner bottom_left_corner",
    107: "ew-resize e-resize w-resize col-resize size_hor sb_h_double_arrow h_double_arrow left_side right_side split_h",
    108: "ns-resize n-resize s-resize row-resize size_ver sb_v_double_arrow v_double_arrow top_side bottom_side split_v",
    109: "move fleur size_all",
    110: "not-allowed no-drop forbidden crossed_circle circle dnd-no-drop",
    111: "progress left_ptr_watch half-busy",
    112: "help question_arrow whats_this left_ptr_help dnd-ask",
    113: "pencil",
    114: "pointer hand hand1 hand2 pointing_hand",
    32654: "all-scroll",
}

def dib_pixels(dib):
    """Cursor DIB (XOR bitmap + AND mask, bottom-up) -> rows of (r, g, b, a, invert)."""
    hsz, w, h2, _pl, bpp = struct.unpack_from("<IiiHH", dib, 0)
    h = h2 // 2
    ncol = struct.unpack_from("<I", dib, 32)[0] or (1 << bpp)
    pal = [dib[hsz + 4 * i:hsz + 4 * i + 3][::-1] for i in range(ncol)]
    xstride, astride = ((w * bpp + 31) // 32) * 4, ((w + 31) // 32) * 4
    xor = hsz + 4 * ncol
    andm = xor + xstride * h
    rows = []
    for y in range(h):
        sy, row = h - 1 - y, []
        for x in range(w):
            bit = sy * xstride * 8 + x * bpp
            idx = (dib[xor + bit // 8] >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
            transparent = (dib[andm + sy * astride + x // 8] >> (7 - x % 8)) & 1
            if not transparent:
                row.append((*pal[idx], 255, False))
            elif pal[idx] == b"\0\0\0":
                row.append((0, 0, 0, 0, False))
            else:
                row.append((0, 0, 0, 255, True))  # inverts the screen
        rows.append(row)
    return w, h, rows

def render(w, h, rows, scale):
    """Premultiplied ARGB with XP's cursor drop shadow (opaque mask shifted
    2,2 under a 3x3 box blur, up to alpha 0x50). Screen-invert pixels become
    black with a white rim: Xcursor has no XOR mode."""
    solid = [[rows[y][x][3] == 255 for x in range(w)] for y in range(h)]
    inv = [[rows[y][x][4] for x in range(w)] for y in range(h)]
    def near(grid, y, x, d0, d1):
        return sum(grid[j][i] for j in range(y + d0, y + d1) for i in range(x + d0, x + d1)
                   if 0 <= j < h and 0 <= i < w)
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b, a, _i = rows[y][x]
            if a == 255:
                row.append((r, g, b, 255))
            elif near(inv, y, x, -1, 2):
                row.append((255, 255, 255, 255))
            else:
                row.append((0, 0, 0, near(solid, y, x, -3, 0) * 0x50 // 9))
        out.append(row)
    px = lambda r, g, b, a: struct.pack("<I", a << 24 | (r * a // 255) << 16 | (g * a // 255) << 8 | b * a // 255)
    return b"".join(b"".join(px(*p) * scale for p in row) * scale for row in out)

def xcursor(path, out):
    """Nominal 24 = XP's own pixels (32x32 canvas, as XP drew them at 96 dpi);
    nominal 48 = the same doubled with nearest neighbour."""
    res = {(label, name): blob for label, name, blob in resources(path, {"CURSOR", "GROUP_CURSOR"})}
    cdir = os.path.join(out, "cursors")
    os.makedirs(cdir)
    for gid, names in XCURSORS.items():
        nid, = struct.unpack_from("<H", res[("GROUP_CURSOR", gid)], 6 + 12)
        c = res[("CURSOR", nid)]
        hx, hy = struct.unpack_from("<HH", c, 0)
        w, h, rows = dib_pixels(c[4:])
        imgs = [(24, 1), (48, 2)]
        chunks = [struct.pack("<9I", 36, 0xFFFD0002, n, 1, w * s, h * s, hx * s, hy * s, 0) + render(w, h, rows, s)
                  for n, s in imgs]
        toc, pos = b"", 16 + 12 * len(chunks)
        for (n, _s), ch in zip(imgs, chunks):
            toc += struct.pack("<3I", 0xFFFD0002, n, pos)
            pos += len(ch)
        names = names.split()
        with open(os.path.join(cdir, names[0]), "wb") as f:
            f.write(b"Xcur" + struct.pack("<3I", 16, 0x10000, len(chunks)) + toc + b"".join(chunks))
        for n in names[1:]:
            os.symlink(names[0], os.path.join(cdir, n))
    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=Windows XP\nComment=Windows XP's standard cursors, converted from user32.dll\nInherits=Adwaita\n")

def halfblock(src, dst, mode):
    """Binary PPM (P6, maxval 255) -> text, two pixel rows per line. color:
    U+2580 with 24-bit fg = top pixel, bg = bottom pixel, black left to the
    terminal (the XP boot logo is on black). mono: pixels brighter than 96
    become U+2580/U+2584/U+2588, for the stock screensaver's plain text."""
    d = open(src, "rb").read()
    head = d.split(maxsplit=4)
    assert head[0] == b"P6" and head[3] == b"255", "need a binary P6 PPM"
    w, h = int(head[1]), int(head[2])
    px = d[len(d) - 3 * w * h:]
    get = lambda x, y: tuple(px[3 * (y * w + x):3 * (y * w + x) + 3]) if y < h else (0, 0, 0)
    lines = []
    for y in range(0, h, 2):
        out = ""
        for x in range(w):
            t, b = get(x, y), get(x, y + 1)
            if mode == "mono":
                on = (sum(t) > 288, sum(b) > 288)
                out += {(0, 0): " ", (1, 0): "▀", (0, 1): "▄", (1, 1): "█"}[on]
            elif t == b == (0, 0, 0):
                out += "\x1b[0m "
            elif b == (0, 0, 0):
                out += "\x1b[0;38;2;%d;%d;%dm▀" % t
            else:
                out += "\x1b[38;2;%d;%d;%d;48;2;%d;%d;%dm▀" % (t + b)
        lines.append(out.rstrip() + ("" if mode == "mono" else "\x1b[0m"))
    while lines and not lines[-1].replace("\x1b[0m", "").strip():
        lines.pop()
    open(dst, "w", encoding="utf-8").write("\n".join(lines) + "\n")

def dib_rows(dib):
    """BITMAP resource DIB (BI_RGB 1/4/8/24/32 bpp, BI_RLE8, BI_RLE4) -> w, h, top-down rows of (r, g, b)."""
    hsz, w, h, _pl, bpp, comp = struct.unpack_from("<IiiHHI", dib, 0)
    ncol = (struct.unpack_from("<I", dib, 32)[0] if hsz >= 36 else 0) or (1 << bpp if bpp <= 8 else 0)
    pal = [tuple(dib[hsz + 4 * i:hsz + 4 * i + 3][::-1]) for i in range(ncol)]
    bits, topdown, h = hsz + 4 * ncol, h < 0, abs(h)
    if comp in (1, 2):  # RLE8 / RLE4: (count, value) runs and escapes, bottom-up
        idx, x, y, p = [[0] * w for _ in range(h)], 0, 0, bits
        nib = lambda b, k: b if comp == 1 else (b >> 4 if k % 2 == 0 else b & 15)
        def put(v):
            if x < w and y < h:
                idx[y][x] = v
        while p + 1 < len(dib):
            n, c = dib[p], dib[p + 1]
            p += 2
            if n:
                for k in range(n):
                    put(nib(c, k)); x += 1
            elif c == 0:
                x, y = 0, y + 1
            elif c == 1:
                break
            elif c == 2:
                x, y, p = x + dib[p], y + dib[p + 1], p + 2
            else:
                for k in range(c):
                    put(dib[p + k] if comp == 1 else nib(dib[p + k // 2], k)); x += 1
                nbytes = c if comp == 1 else (c + 1) // 2
                p += nbytes + (nbytes & 1)
        rows = [[pal[v] for v in r] for r in idx]
    elif comp == 0:
        stride, rows = ((w * bpp + 31) // 32) * 4, []
        for y in range(h):
            r, row = dib[bits + y * stride:bits + (y + 1) * stride], []
            for x in range(w):
                if bpp <= 8:
                    b = x * bpp
                    row.append(pal[(r[b // 8] >> (8 - bpp - b % 8)) & ((1 << bpp) - 1)])
                else:
                    o = x * bpp // 8
                    row.append((r[o + 2], r[o + 1], r[o]))
            rows.append(row)
    else:
        sys.exit("unsupported BMP compression %d" % comp)
    if not topdown:
        rows.reverse()
    return w, h, rows

def png(path, w, h, rows):
    """RGBA rows -> PNG. Stored (uncompressed) deflate blocks, so the bytes
    never depend on the zlib build and the output can be pinned by sha256."""
    import zlib
    raw = b"".join(b"\0" + bytes(c for px in row for c in px) for row in rows)
    z = b"\x78\x01"
    for i in range(0, len(raw), 65535):
        blk = raw[i:i + 65535]
        z += bytes([i + 65535 >= len(raw)]) + struct.pack("<HH", len(blk), len(blk) ^ 0xFFFF) + blk
    z += struct.pack(">I", zlib.adler32(raw))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", z) + chunk(b"IEND", b""))

def strip(path, out, spec):
    """A BITMAP that is a horizontal strip of equal frames (batmeter.dll's
    tray battery: 300 is 32 px x 10 plus a stray column) on a colour key."""
    rid, fw, key = spec.split(":")
    fw, key = int(fw), tuple(bytes.fromhex(key))
    dib = next(blob for label, name, blob in resources(path, {"BITMAP"}) if str(name) == rid)
    w, h, rows = dib_rows(dib)
    os.makedirs(os.path.join(out, str(h)))
    for n in range(w // fw):
        frame = [[(*px, 255) if px != key else (0, 0, 0, 0) for px in row[n * fw:(n + 1) * fw]] for row in rows]
        png(os.path.join(out, str(h), "%d.png" % n), fw, h, frame)

if sys.argv[1] == "peres":
    peres(sys.argv[2], sys.argv[3], set(sys.argv[4].split(",")))
elif sys.argv[1] == "icons":
    icons(sys.argv[2], sys.argv[3], {int(s) for s in sys.argv[4].split(",")})
elif sys.argv[1] == "bootpal":
    bootpal(sys.argv[2], sys.argv[3])
elif sys.argv[1] == "xcursor":
    xcursor(sys.argv[2], sys.argv[3])
elif sys.argv[1] == "strip":
    strip(sys.argv[2], sys.argv[3], sys.argv[4])
elif sys.argv[1] == "halfblock":
    halfblock(sys.argv[2], sys.argv[3], sys.argv[4])
else:
    sys.exit("usage: see docstring")
PY

# ── Sources: key | sha256 of the downloaded bytes | URL ──────────────────────
SOURCES=$(cat <<EOF
FRAMD|55d0870dcb8c34ba4c8d0562fea6907f7fd8a19457e3af387600789050523172|$ISO/FRAMD.TT_
FRAMDIT|dd651316febb19c1c9ac99ceed025a40dda6676e9022600964b332a89eee43e7|$ISO/FRAMDIT.TT_
LUCON|34e44c83a9c8078fa611c16bb3b2b1dd8c612923d09fbcabaf312af650880511|$ISO/LUCON.TT_
TAHOMA|eb107c36fada2a6c4f85ec9328297f19add8cfda3f3c0802d3f1647712454277|$ISO/TAHOMA.TT_
TAHOMABD|0bf022886a919a79e0ca38b566a76456e7ce7d70a868b451a74003edf96cc0fa|$ISO/TAHOMABD.TT_
TREBUC|3d43f485d6da8ddc46e7c21e9eecad53a2d33b633e72606842f1419d16c736e7|$ISO/TREBUC.TT_
TREBUCBD|e103880dab3aef92ebac20a5c3e6d067ce3aa9c6aee2cdb549777e3f028ccf8b|$ISO/TREBUCBD.TT_
TREBUCBI|a5773b9563b052f859cfa5ce3772e3d3b154ce7b43059bab21ecd49a31de1c53|$ISO/TREBUCBI.TT_
TREBUCIT|7033830f6ce3b137e9eadc3429e4db50cd844250187018909dfbccb13e2ea15d|$ISO/TREBUCIT.TT_
XPBALLN|73d1e7fa864d5ed3b6f7a46830d3874e0db89ec1bae5c8062c25069cad4e0637|$ISO/XPBALLN.WA_
XPBATCRT|97185c9fd527a041fe45eedbd3a152adf885dc160a66215032386d80dfe7e061|$ISO/XPBATCRT.WA_
XPBATLOW|3983234a85069e9bd76f69222beb3c47ecaa9cbba20a899004e9eb91f6481f43|$ISO/XPBATLOW.WA_
XPBLKPOP|0efe139beb7c349949ca49a66cb52fbaffb1f0f5932efe56ca39c57ad02c1831|$ISO/XPBLKPOP.WA_
XPCRTSTP|9c5c3500cb7f2cfab23a5903d91f217f6a0110e1906e6bdc972bfc13584162de|$ISO/XPCRTSTP.WA_
XPDEF|97b62dcebdfac975908ca8c3edbc5523c1287567e50541a4d69cbf0128b21409|$ISO/XPDEF.WA_
XPDING|7f1dfa8091208d3952b71189085f236ed7838032f75cb65eed95696ce468a900|$ISO/XPDING.WA_
XPERROR|9c4aec17aa5731bdd5272acf13d50d7deda8a74f072b438db50de5785a935630|$ISO/XPERROR.WA_
XPEXCL|5772cfa7b9e34b8e7dab9decc683f8c71589b76ad8c7ce6cb62e01aa7c4c00af|$ISO/XPEXCL.WA_
XPHDFAIL|3f8f2ea5aed5b85c3946e51061c1b31389f07946bb04d7304c91928a9f6c2abb|$ISO/XPHDFAIL.WA_
XPHDINST|cb611d2a72975b63261df13f08bc58f7220b07e295d02880ed0e9c079fe0cac4|$ISO/XPHDINST.WA_
XPHDREM|138f5aa522068e2be82671b2c95989f37a2ccbb0ac9a66d49812f89fb9572550|$ISO/XPHDREM.WA_
XPINFBAR|7ac61b5913520f48bc48d3c9013b3f267084690867cdfcdae9594054b6997190|$ISO/XPINFBAR.WA_
XPLOGOFF|205a827e318fa74f1a083778e2b2aa4e67e17874214a6c699f88f1adb3411114|$ISO/XPLOGOFF.WA_
XPLOGON|daa11fe25ec26141656c9a1bd059d550a71ca32689fc38ee120f61f70e8d2597|$ISO/XPLOGON.WA_
XPMENU|74767cc6f445d62c9888885f391e47a575f0956c8ad4575edabde76631bf5743|$ISO/XPMENU.WA_
XPMIN|56ae4c4e4dc7ab145461cf55c971b69c270ac16889540bf4ae2a6d9a5c7d6c2e|$ISO/XPMIN.WA_
XPNOTIFY|d9c55f3aebb268362871b9e38fe732227a0bfede466e7daf8d0401f2e0a4d829|$ISO/XPNOTIFY.WA_
XPPRINT|abe41dd2e11191e04932fc3b3ab92aff0f251aba810fbe1ec1aa25d421790e40|$ISO/XPPRINT.WA_
XPRECYCL|2213c55bf0af65f10e272f6cbc43242909bc56b6592af9c7597d1cd1fb62e320|$ISO/XPRECYCL.WA_
XPRESTOR|99c2f7bebfe7dd8583264037b269ce7abd9a7663344c79c9ea4847cce1a87670|$ISO/XPRESTOR.WA_
XPRINGIN|385e7ee7c5059828da51c59d0bfe89c1f0d14009a660c56ae12011d6f22e529b|$ISO/XPRINGIN.WA_
XPRNGOUT|4c711c4b64cb9b11a4cecf23b368e81ec1fc71c2887e2d66bd03d26f3d3aa931|$ISO/XPRNGOUT.WA_
XPSHUTDN|295cd4b96a3bc567355fe5c68b2b0472f8d670e9f513e3c5b811249c760d1038|$ISO/XPSHUTDN.WA_
XPSTART|70958c4c91cf51f7113f00ade7991ba02bb42f1a8585acf274e2bc32c2163f56|$ISO/XPSTART.WA_
XPSTARTU|1bf5840d2ab04e52fe9792a4d3b0924f37a36d3d267027f6a151f3bcaeecf706|$ISO/XPSTARTU.WA_
ASCENT|79dca4293000bfa89b28a31778264ef5dcba545ebf1fb018dbb822f3043e357b|$ISO/ASCENT.JP_
AUTUMN|1e6cbd57a9df31084a3d8902d6df0226fffa10904ae391c0a39a058815562e8a|$ISO/AUTUMN.JP_
AZUL|3559aa2647b9600db8f64d52f6e15d35c84c09a879f38723611f1841c30dc337|$ISO/AZUL.JP_
BLISS|4fd6799156da6dc6054facbf8780331ea26ff133f8f797fb282a2e0606afc770|$ISO/BLISS.JP_
CRYSTAL|ef2a4aa44ebf2afc38399d05674efabe7ceaa0d646d7271402100773c1550575|$ISO/CRYSTAL.JP_
FOLLOW|094944e3ef444c782708234c751a98aa394ecfd0fca6e381f0855876ad21b259|$ISO/FOLLOW.JP_
FRIEND|69ffbbd746a3008823d5680991b0082785feb78f9b8004563a2fda3367451e7d|$ISO/FRIEND.JP_
HOME|1cc8c39f15a61d1677c1ccf6573dfed184cde5fd39bb470651073b82b863689b|$ISO/HOME.JP_
MOON|e6238d9cbc90f4a564f98284a451cb8138162cc54458564ebe3e7443d47cb29a|$ISO/MOON.JP_
PEACE|660adc22737a7f3159107fe7a88743e17100d067a624afc8b2ce5ad9aef0d93f|$ISO/PEACE.JP_
POWER|aa5046fa81c74b3a1e1856765118489d0127a4b3f1ea8e76686e815aed2b8d7a|$ISO/POWER.JP_
PURPLEF|bffd11149ed53d08cee1de1323d627201f5978fb284bcfa0af771d286e90a536|$ISO/PURPLEF.JP_
RADIANCE|5b22a1f223c7e992a1115530f4f2c7f3f2e8b7393714e81da127fe6e22569e6b|$ISO/RADIANCE.JP_
REDMOON|d1bb59bf91223ee27851d4ebb966d86ba152dc11bde157ac824c8c95265bced1|$ISO/REDMOON.JP_
RIPPLE|3c4b02464e9723c5671b1a149eccb48ae227a004bcfee9efaba1f07ae749985a|$ISO/RIPPLE.JP_
STONEH|f2598084b0d7754438b037a44c59b951c714446f798ee7e10ab41a26465230f1|$ISO/STONEH.JP_
TULIPS|5a5ff51291f355256e7867194adf33c599cbf1544508b4c3666cd935b41ced07|$ISO/TULIPS.JP_
VORTEC|ab954e0ef92b28b33eb9777c3f75f791eb5f9853dfc211227b195b9934f2a9de|$ISO/VORTEC.JP_
WIND|699487e1cb2fb156bd145a9c6b48d4360b2325648e29648ade1ec4492636c930|$ISO/WIND.JP_
WINXP|4f10c044f1e8bdc0a8c80691a8ffd497232eb309bd91f4c572ee1c546c223e9a|$ISO/WINXP.JP_
AIRPLANE|3cb1afd5edf24ed10fab6543ee0b2e4429b20b1643a36a631ddd9444e421babc|$ISO/AIRPLANE.BM_
ASTRO|3785d026381cfc054d8382dd5fb8c6a93f6c8bbd82e254e1ab1ddc619592fc15|$ISO/ASTRO.BM_
BEACH|2d1967957cc9c0ad9ab94d405b974235bf4434053586884ffe6df7f90e7e1d08|$ISO/BEACH.BM_
BUTTERFL|418f309993c87fdacf7ac8676add4ac96c36f0f944fe59f454051c8fff07b7d0|$ISO/BUTTERFL.BM_
CAR|821e11609fc5725269ab4b860e1fdab974447b9e2dd6214a286eb4cbc5526d7e|$ISO/CAR.BM_
CAT|3f8462e2a074fdd01769ba0b4876a91da041c7e9b965df44fd22205d935095a5|$ISO/CAT.BM_
CHESS|75ad60e0762838499d1853be4524b4e79ff19a0dc1ddf308a4a8d7e20d2fd334|$ISO/CHESS.BM_
DIRTBIKE|50ee63a8de801441eb41f0a80233ed8a1fc2a198161bf1308558359167fbad3e|$ISO/DIRTBIKE.BM_
DOG|4586bfe4e8aa87d352804251e8219c154a44aeabfd262c746934c4fbdbc4e1af|$ISO/DOG.BM_
DRIP|9850bd4491abc2f7fac8e98aa04bce916fda31103181638bb5cb4373601806d2|$ISO/DRIP.BM_
DUCK|c6c7c50222f5b2aaacf8ac4d7bee332976163773a889deb8f888642924bf4107|$ISO/DUCK.BM_
FISH|6ddd5a5fed5daaad5dac62ea14da7bcbf91b1902ff373454aa462d6ace9c161b|$ISO/FISH.BM_
FROG|54b2fb7692c4e443548dbc4e4e1dc19c4b596f1d2274b18967a761fbfa91a9fb|$ISO/FROG.BM_
GUEST|dac5896d876982e574c291821dbadf97d99342a51a5a706a9968cb2f1a5eaddc|$ISO/GUEST.BM_
GUITAR|cc886b2504ee37584efdfbfae887b453ed116696bd95175a3610c127cf4f4739|$ISO/GUITAR.BM_
HORSES|5e90863bbb70d07d2170a965cd3287922e99dc60fdaff5917c0a5d3b3eab526d|$ISO/HORSES.BM_
KICK|29d5a3c3e85f8008f84e350b57388f5e25617a79b19c9c8ddc0a762d19f3da98|$ISO/KICK.BM_
LIFTOFF|ae556b75d263598aee1401c4f5128f6a7937d8c5c9d0af9e28afe9811b9e8126|$ISO/LIFTOFF.BM_
PALMTREE|5d1096a784c5f7e53610a53dbc1c1bb39468d69bc15a82fd60368b5fa2611af9|$ISO/PALMTREE.BM_
PNKFLOWR|9af5149672981d1e74943b5390c768019a551d816e73e9a7ba10c8b9bd820a3e|$ISO/PNKFLOWR.BM_
REDFLOWR|7d92dbb8ad0047d4e099818344c04c274e0f95bc499af105badc52a568ae3373|$ISO/REDFLOWR.BM_
SKATER|6284938e92d4b0b8274a5701b7346207e989efdf6ed1cdcf309efa0d8fe88a05|$ISO/SKATER.BM_
SNWFLAKE|e35550f1809aebcce347dd44fc3559531df823eae219823295ca225d0d1ed73f|$ISO/SNWFLAKE.BM_
SOCCER|353782532478df9ad7d8f2478d633e0196e5fd2be50fcc9cb097acb0ddc79b80|$ISO/SOCCER.BM_
LUNA|a98d8161df17033d12ebaba29dd467960072f14e27dd4f893fc3e5cf6c3c648a|$ISO/LUNA.MS_
NTOSKRNL|fc84d920bb12e1b911237e2e18c2cbbc32c8a1700f6c49eee49659335b95e269|$ISO/NTOSKRNL.EX_
EXPLORER|6a7b829988e52b1d4a7cab6980a50a6087232277ae1065dc3afb7ed145255eed|$ISO/EXPLORER.EX_
LOGONUI|8d06161915c0df2998f7fcaa9b24ce75c708099c8bf9bb853f1107b2fe6c4da6|$ISO/LOGONUI.EX_
MSGINA|d7616b234e7fe251bd604724ff048b378c598b1eb8126b35fe5acc74a7662aa2|$ISO/MSGINA.DL_
SHELL32|ad0c40de296b3ed81e187f4e6df1f58c5c1ac28e2f444f219037ef81399f61a7|$ISO/SHELL32.DL_
USER32|a9e1eec98d0bb4bc6d3787ed45a650d0c7bc6674941f551d9bbaa7f485ea040f|$ISO/USER32.DL_
STOBJECT|fe673eb3774f257874a756e456dbf701c9c6afb880660cf198f9db76bdca5608|$ISO/STOBJECT.DL_
BATMETER|24f1c53a0a2d40004a9ba6b1ceba675094faa129ec29e67e191c03e7fb89bc94|$ISO/BATMETER.DL_
NETSHELL|18f546092e7ca6fb7b8b3d2ca429d80e2a49c6cb5bccabe19e6b5c6c918408cd|$ISO/NETSHELL.DL_
WUAUCLT|e98fbeec7d173bc586618af0079036972eab61863fa1b3770d3a3a52d1b9e1b1|$ISO/WUAUCLT.EX_
MMSYS|aef3f77813c149e3cef23b6b7d2f75803a01754056f93b04ed9fb9cdb5150286|$ISO/MMSYS.CP_
DESK|a03edfbb41b17813a5ea0b7d26bab4f0747f465cfce181ee9302cc05c75836bf|$ISO/DESK.CP_
POWERCFG|d4b1e1552e4a5b147af882c5233fc6f1694369a7f3bde35be0e31b548fb4aedc|$ISO/POWERCFG.CP_
AGENTSVR|f60907c100ef68ed67e0694778ee67374ce6ad2ec60373749c8455ffd2054d41|$ISO/AGENTSVR.EX_
FSQUIRT|2c0606dc2c783c190e5b7794bbbc25dd4ca512680846790ad3f9f15e3931ae7c|$ISO/FSQUIRT.EX_
XPSP2RES|4a1abe0a5d7f96fc571ad4e663a4e2b0358504b3c560cb725c12b7456371bf1b|$ISO/XPSP2RES.DL_
THEMEUI|91a41e8d5d05c0babc5da3c86ef6c76048c8b12d755c7cba5626c4c3022fad5d|$ISO/THEMEUI.DL_
TIMEDATE|3754842f94f4b92cf8af808b2212bf5a066b2a6bcd4f30fcf7151cb09820011d|$ISO/TIMEDATE.CP_
SNDVOL32|2ce9c878d2ab44b788a431cf13c0454ad15367d1e0706cfb378add5aa207d8c3|$ISO/SNDVOL32.EX_
INPUT|2d04c0c37aedb548a01c3aeaa9960c915805ca48875859195217e1120b95ae66|$ISO/INPUT.DL_
MSCTF|5d0ee7f29363d31dcbdc2714fb4261092c5b2b05ef5ff82c984511264e66f776|$ISO/MSCTF.DL_
HIVEDEF|00efcf4da1f58f7798b2a48001b1699ade27753698725056f8e0dbb7135e5189|$ISO/HIVEDEF.INF
BLISS600|a72d44ee40c406a1b8837a94e7fc8834bd7f6f22e8c5da9aa28da9d5922d47da|https://archive.org/download/bliss-600dpi/bliss-600dpi.png
AUTUMNHR|3e4be6eaf5f1cb1b52d09db6084df5d8a57da3220144909c0795de2175ff3eac|https://archive.org/download/windows-xp-autumn/CB040538.jpg
ROYALEZIP|5e79f2e40eb8fad665b15827e251ad319abed5edd52068bf2b16a7d64d6f5d74|https://archive.org/download/royale-theme_202607/Royale_theme.zip
ZUNEMSI|a447ba38983d870a07067a5289d6552a4146b817fb77876940c7f9343ba1abf9|https://archive.org/download/zune-desktop-theme_202109/ZuneDesktopTheme.msi
XPGTK|d1b23679eb66ac6cc8278736ed87b7dbf2be17d23fe11c6dc63b5cc0336ebb31|https://codeload.github.com/B00merang-Project/Windows-XP/tar.gz/7637830906823af40a3cd7e7079be753d8b7d679
XPICONS|aeed64f644baa922ac33480088765e57640d95450831ace7d72b511b8458ac2a|https://codeload.github.com/B00merang-Project/WinXP-Icons/tar.gz/24e95ad2b12c55dd11883ee7066525527d944039
R_BOOT|6fb6c4cc953f0c721c7e48656f15008c0f5c132b76540eb239ecea3198c1e841|https://upload.wikimedia.org/wikipedia/commons/8/8a/Windows_XP_Professional_boot.png
R_LOGIN|cd049bfeb497de49b8e93c0285da218bfdf2a77aaf6dca77a11335c9bd464584|https://upload.wikimedia.org/wikipedia/en/5/57/XP_login.png
R_LUNA|55c204cee4bdede24dcae87217c9e2fc3d1e255b55a78b09cbf3eec97944fcc4|https://upload.wikimedia.org/wikipedia/en/6/64/Windows_XP_Luna.png
R_OLIVE|fdbce99dd98eeaa81622a5c9fad2e6b7e979aefe61e9d9ea8033c36310ee0caf|https://upload.wikimedia.org/wikipedia/en/3/3a/Windows_XP_Olive_Green.png
R_SILVER|4373a4ea6cf36af82f32a400999cd812e5c5d60da6f1240e8f5b7b28bbb83d18|https://upload.wikimedia.org/wikipedia/en/1/1c/Windows_XP_Silver.png
R_ROYALE|870d5cda51641ba7f878f54b94f8ce60e2eea26b9b4c40e37cac216d6c951f28|https://upload.wikimedia.org/wikipedia/en/4/47/Windows_XP_Royale.png
R_ZUNE|134109839b2db8fbf7dd3a69010faafbae94bae49880bef00c16b1aba700e152|https://upload.wikimedia.org/wikipedia/en/3/38/Windows_XP_Zune.png
R_MCE|6ba7ab9b5cd092abed5e38bd8344efd43c9025204195e893102b98b11fa9768a|https://upload.wikimedia.org/wikipedia/en/5/56/Windows_XP_Media_Center_desktop.png
R_X64BLUE|4b87922d3f7c2622108a59538c7983769125917a090f5210f0ef17f6ea3af7ef|https://upload.wikimedia.org/wikipedia/commons/f/f1/Windows_XP_x64_screenshot_%28blue_theme%29.png
R_X64OLIVE|8c61216858e67be2319c9902ff04015f0334f796142466195fe0b1e5d68e56df|https://upload.wikimedia.org/wikipedia/commons/6/68/Windows_XP_x64_screenshot_%28olive_green_theme%29.png
R_X64SILVER|dec835bb78a9b014ab9407fb8c5b534e6770fdf64c82f418d7e20aa2b751b226|https://upload.wikimedia.org/wikipedia/commons/0/09/Windows_XP_x64_screenshot_%28silver_theme%29.png
R_START|3d68ed49a9d240218bcb96eefc86b4da6dddeba7046350c087aa6f0d1bb267e5|https://upload.wikimedia.org/wikipedia/en/e/ef/Windows_XP_Start_menu.png
R_STARTROYALE|e950aaa21720bacee22be6dd2852c16dab1b9cf9ce46c808769bebcf2a6a9925|https://upload.wikimedia.org/wikipedia/en/a/a5/RoyaleXP2.PNG
R_GROUPING|ca1ba795898d0e2e414695befbd3766792204f29e21b481a7077a2df7ba090ea|https://upload.wikimedia.org/wikipedia/en/7/71/Windows_XP_task_grouping_%28Luna%29.png
R_TURNOFF|0200c1fc660f155d2f7b611c66291826435b10ddfee01c5d2e4f6c7bcaf8208e|https://upload.wikimedia.org/wikipedia/en/5/5e/Windows_XP_Shutdown.png
R_CMD|cb8b859063327f946452f357770ea96c4f439ff4b7600a9bd3c1dbd83311bb65|https://upload.wikimedia.org/wikipedia/en/6/6c/Ipconfig_win_xp.png
R_CMDBANNER|b37068ef0c4f0b20d9aaed0dc01df60ef400d43741ac207627f767460b9660bc|https://upload.wikimedia.org/wikipedia/commons/3/36/Command_Prompt_on_Windows_XP_%28Czech%29.png
R_TASKMGR|12c9fcf308097700f8238315ab78aed0963bdd6b6473021ce0d24d707ac78f3f|https://upload.wikimedia.org/wikipedia/en/6/6b/System_idle_process.png
R_AUTOUPD|53b5835d3d27c564f91af3ef8b4079ef5be991ec3b02c7c5d1e0b0e87f85f9d1|https://upload.wikimedia.org/wikipedia/en/2/2b/Winautoupdates.PNG
R_SEARCHCOMP|3db280beb3f28dcb4d5b81c1280cabfe7aa215ed45b4c92c610c6046be06b6e6|https://upload.wikimedia.org/wikipedia/en/9/90/Windows_Explorer_search_puppy.png
R_EXPLORER|a21830d48ffdae542159e0e83c286942c99ba8b764363ee86cea28f8c0fc3c7d|https://upload.wikimedia.org/wikipedia/en/c/c0/Windows_Explorer_XP.png
EOF
)

# ── Outputs: dest (under assets/) | sha256 (tree hash for dirs) | method | source | member
#   raw      the download itself
#   cab|7z|zip  unpack the source into a fresh dir with that tool, take <member>
#               (member "-" = the archive holds exactly one file)
#   peres    parse PE resources of a local file (@path) into a directory; member = types
#   icons    GROUP_ICON resources of a local file (@path) as one-image .ico files,
#            <size>/<id>.ico; member = sizes. PNGs are derived by bin/xp-taskbar-art.
#   bootpal  BITMAP <member> of @binaries/ntoskrnl.exe with the recovered boot palette
#   xcursor  user32.dll's cursors as an Xcursor theme (xptool.py xcursor)
#   strip    BITMAP <id> of a local file cut into <w>-px frames, colour key
#            transparent, as PNGs <h>/<n>.png; member = <id>:<w>:<rrggbb>
# A zip/7z member may be a directory (the GTK and icon themes): its tree hash
# then covers symlink targets too, and links leaving the tree are refused.
OUTPUTS=$(cat <<'EOF'
fonts/framd.ttf|f103d31608ff1fa1b861ff297b16a49a74441dae98ce12c506a7085c01de9a11|cab|FRAMD|-
fonts/framdit.ttf|02bf3f5c3289f66a314e9758f48ad729e3995b26ad74887b04ebbf0d775b2492|cab|FRAMDIT|-
fonts/lucon.ttf|6ddf64ee896d24cf9908f115ae220a7cfa18dc034bc4a68e4db68dcd57c71512|cab|LUCON|-
fonts/tahoma.ttf|08f45bf539954d3252df97a2ae563362ed2ad5ebe05f2d1f2bc54b931e4d0550|cab|TAHOMA|-
fonts/tahomabd.ttf|4ba89e145ff39f208151ce269841899fc4e4a360189a4a31dc2359168dae27d0|cab|TAHOMABD|-
fonts/trebuc.ttf|9cf5777ebf93e9193d25ec0697976bb2dcad1637b73e9e36cfbf18d26ef262a9|cab|TREBUC|-
fonts/trebucbd.ttf|73150ef5306b3651eac743ad570bc956c2ca41f5564e8700c8ae83928827441e|cab|TREBUCBD|-
fonts/trebucbi.ttf|c0a6bdf31f9f2953b2f08a0c1734c892bc825f0fb17c604d420f7acf203a213b|cab|TREBUCBI|-
fonts/trebucit.ttf|db56fdac7d3ba20b7aededcb6ee86c46687489d17b759e1708ea4e2d21e38410|cab|TREBUCIT|-
sounds/balloon.wav|c9de87a87b68dd754fa29f2989c240949ad9b1f0423d019ca68afcd86e107639|cab|XPBALLN|-
sounds/battery-critical.wav|cb02dd9f8b4d18aab9a5c51a26faac12e861dd362800a12292f243432a982325|cab|XPBATCRT|-
sounds/battery-low.wav|bd4a58b1e2b8e93bcf5b76df3e4a9f67ce0926107a5702ed6bac0e63466a22fd|cab|XPBATLOW|-
sounds/popup-blocked.wav|df7cad111688dadb00469203dd7228df99e49e86ae7ba937e308d947cd9790f2|cab|XPBLKPOP|-
sounds/critical-stop.wav|1b86a1b8b7b5925f9346b64115b0b92744a142b06b09f44263a57419bc2bb6e6|cab|XPCRTSTP|-
sounds/default.wav|d0426433cb153f860f02320408a1922558742bc3d170eb47715192ff86a66a16|cab|XPDEF|-
sounds/ding.wav|20fc59d9f846bc32b899880fae0878208856718b75e6158526308b900af8a9bd|cab|XPDING|-
sounds/error.wav|4b51ec1b1b14889bc2c2cdad8c80dafc974d78b9292c3ccb344e44e93383cac4|cab|XPERROR|-
sounds/exclamation.wav|b57b8e8818c424452ca4fb8abb219ae01c0e31db2f955e1f85d9fcb5a0dabfbe|cab|XPEXCL|-
sounds/hardware-fail.wav|fe6e852ff646c0a896995632f76a3e390bea6163b40639c87bf45c1d8a7475c2|cab|XPHDFAIL|-
sounds/hardware-insert.wav|a3e44db9179591a705baed6daa00efb988197c0698a9747980126d5939e9d506|cab|XPHDINST|-
sounds/hardware-remove.wav|c4d09c6ad6a9090c4e611330a7501f7a84abc7c777c6e3d1915179f8d1ed45f3|cab|XPHDREM|-
sounds/information-bar.wav|b4dfbdfd8d6a102123a7966da358781bd32bb6d78e833514705cb7de76efa410|cab|XPINFBAR|-
sounds/logoff.wav|e0c0e5dea2550c8f235c0bb1584d9011a35ca23bc18597bf7ac6581efcd7b7aa|cab|XPLOGOFF|-
sounds/logon.wav|8d71fba4267fb3454030c7289079421a08fc3e773caa47107d832f855ae85396|cab|XPLOGON|-
sounds/menu-command.wav|da4fc6f8917b97725e6de85bb45b574c7895ec46672e6eb439a462cfd9940ac7|cab|XPMENU|-
sounds/minimize.wav|974da6baee4187c37e514186b99691132988140cca95402589c6fdc1417e5926|cab|XPMIN|-
sounds/notify.wav|760cdd5685008255d6e188a8c528ebcb74daf806bb24a81c2a36086df6a95c76|cab|XPNOTIFY|-
sounds/print-complete.wav|e411c02471876c4d1075ec8fcd406e99ac7c9a5e0c6322ed579de50c8ca3b844|cab|XPPRINT|-
sounds/recycle.wav|a8a7028f9fe989cdde61bf22b73f0ff23ae291dbf8e056bb09682a7487c49ad7|cab|XPRECYCL|-
sounds/restore.wav|480dea5b1808dd67c5a5946e7a47e8e582d5cb1c7fdce4b037140157da0ecadf|cab|XPRESTOR|-
sounds/ringin.wav|b2cd4e4a977606abb8c35b7d446d6c322ee4bda4c0c722ef240f0c51d7ddc713|cab|XPRINGIN|-
sounds/ringout.wav|d994081372c2794642da68212d49c6a64263f88a9fde5cc96583b43574c26bb0|cab|XPRNGOUT|-
sounds/shutdown.wav|3d937337075a647950f6aa557bca23dea6e17cf6d14814ca7dbc55b827678a0b|cab|XPSHUTDN|-
sounds/start-navigation.wav|d5712a8963eb3e1e181b25649ecff3080ede89c96350eb07e7d7cad429e959ea|cab|XPSTART|-
sounds/startup.wav|8f859ebb90247036ced11db854848abe1434dc3ffdfa5795f7c5f06db9a423d5|cab|XPSTARTU|-
wallpapers/bliss-4510x3627.png|a72d44ee40c406a1b8837a94e7fc8834bd7f6f22e8c5da9aa28da9d5922d47da|raw|BLISS600|-
wallpapers/autumn-4200x2800.jpg|3e4be6eaf5f1cb1b52d09db6084df5d8a57da3220144909c0795de2175ff3eac|raw|AUTUMNHR|-
wallpapers/ascent.jpg|6b5e3866752b97f38b9868a81a21185a6fd7fa7711d74533aeacb45e33f0af47|cab|ASCENT|-
wallpapers/autumn.jpg|1d9986cf6f049b3fb874d05dc143f666f256d687b17d0ab70e1bfd7bf519f708|cab|AUTUMN|-
wallpapers/azul.jpg|73eace3d028b59df1e195c5c490130ce328fd6e818098184598ee7e6110792ea|cab|AZUL|-
wallpapers/bliss.jpg|aecf72dc2cb3efd15575f081af8907ff5138d5c342d76b23d3bdb5e4db567720|cab|BLISS|-
wallpapers/crystal.jpg|8a4aa3b1764008de10d5d6073e44bea772c7848d549db0588320e926aedcb6f2|cab|CRYSTAL|-
wallpapers/follow.jpg|50e2837599f6d6d7a93c5d5d5235a0416760bc9c8b11c12047f603bd13e8a073|cab|FOLLOW|-
wallpapers/friend.jpg|36cdbf794361420a59673824fd9bbc4bf0c97eb1ba7917460fbeba5f97a76a9b|cab|FRIEND|-
wallpapers/home.jpg|0b337b96eb63bf26eaa9bd3da9bd4344080c2d846b74f4c24c5a6c8b38f22271|cab|HOME|-
wallpapers/moon-flower.jpg|f41d62dcc6b36aa3b2b813527cb5b4aa43ea50a272a6032d4a7c6c3896033330|cab|MOON|-
wallpapers/peace.jpg|c52887b2f24d78035e90169c97d5f613fc03aa615712779909932fba9580b9e6|cab|PEACE|-
wallpapers/power.jpg|151982effaa897b0e4e1a609ae08304a8d16b1722d78830957e2daeb3cd71a11|cab|POWER|-
wallpapers/purple-flower.jpg|c2dadf25fc5e2c5b81c550a6b3bf028f311933c8e7ea3739f3d2ef6ab14645cd|cab|PURPLEF|-
wallpapers/radiance.jpg|e5a9b2254e517ab3d146e319d70f228f6dd3df793188d8d6ebb29cf46ff6e365|cab|RADIANCE|-
wallpapers/red-moon-desert.jpg|21ca374199995341dcca037bae1dc18eed8a09801afd3217121851e2b638df58|cab|REDMOON|-
wallpapers/ripple.jpg|dbc0aa795775190f396f9c91e8458762669c1d079e0d091b8f481f7cc6cbb9d4|cab|RIPPLE|-
wallpapers/stonehenge.jpg|95d26f5c67a6ec45dca6a0148d12d7801b7f4488177ca3dab662125095b40cc8|cab|STONEH|-
wallpapers/tulips.jpg|9a6924e743e56d164c8a83ecfd2a3aa18cac81beda65c8e5a2f213855ef74b9a|cab|TULIPS|-
wallpapers/vortec-space.jpg|7b4fd2a52b5caabd629df5c1424493d4a9189b008c09162b37bcaf3269dde147|cab|VORTEC|-
wallpapers/wind.jpg|abf1dae685cd2f3aa585bb058cb59b2e30940da84814a9764a59e20ef94999f7|cab|WIND|-
wallpapers/windows-xp.jpg|b8753e74c04ada4f3c5dba5eaee67cb14e82f1a567431153d63771352ba3e005|cab|WINXP|-
binaries/royale-installer.exe|076fb2f71969216a9d75d18daabd37b01cbbbac17b150634521f046cc5910551|zip|ROYALEZIP|Royale Theme for Win XP.exe
wallpapers/royale-energy-bliss.jpg|7b71bdef2789b4daf493002e7f11cc009f28a33b6093b1992a101d9d58885beb|cab|@binaries/royale-installer.exe|Web/Wallpaper/New Bliss.jpg
wallpapers/zune.jpg|da2d9ac5b1f7d33e31e5fcc3a13c6e73ee5761c60825e3b6f726b97c03eaef6e|7z|ZUNEMSI|ZuneJPG
wallpapers/zune-widescreen-1900x1200.jpg|88c1d7a29064b63eb73e7e067d3b5680814d397ce6be490fe537a1b7e17e91cc|7z|ZUNEMSI|ZuneWidescreenJPG
graphics/account-pictures/airplane.bmp|50bc79f388a6f6a3abfd401ede993aa67626207b6ab63320fd44879ef73fda3c|cab|AIRPLANE|-
graphics/account-pictures/astronaut.bmp|5d6f342681f420179a8832d6cfb0a1081a8a7ce1268736ef95a63896137694d5|cab|ASTRO|-
graphics/account-pictures/beach.bmp|ba3f69d25e4e77c54b430ccb1cd5af85fff66ec22689f0db6a9bed4fe3733bfd|cab|BEACH|-
graphics/account-pictures/butterfly.bmp|e2baa4c727ae4ae988ac1b38384cf043e2ac3a67767b37a6049e99fe2d1dfea2|cab|BUTTERFL|-
graphics/account-pictures/car.bmp|5fc50c87b3f84a7496233d9f21f8a577be40d436ab396ecf798a337300a56dcf|cab|CAR|-
graphics/account-pictures/cat.bmp|8dd31725432fd800dc2ff4a95567e2d8c8391385686ad0fe88bc480864e8ddda|cab|CAT|-
graphics/account-pictures/chess.bmp|f5003282e999e6d9704b53812e3713723b37838efdcf8102901c14baa174257a|cab|CHESS|-
graphics/account-pictures/dirt-bike.bmp|dc9657a1a14d27171f4d1653a7ff404b5c77db4824a374c44492fe2dcf12bdec|cab|DIRTBIKE|-
graphics/account-pictures/dog.bmp|4cb21f95bccd80bca6baa955d8f9dcc1837e5a561d1585c9aaecdd7d377db8ab|cab|DOG|-
graphics/account-pictures/drip.bmp|938302353d9e5e040c36fb429ab96cd61b4e0948d1c6c027767f8ae00dc62171|cab|DRIP|-
graphics/account-pictures/duck.bmp|01d3f4fcf587946f892683a96fe4417b877cf8e6ff40ec63c769d5133364d5cd|cab|DUCK|-
graphics/account-pictures/fish.bmp|4f5230f4e5338c433953dfe6fc203f2cb1936ca7ad8a9d6aed0afb583a1639fd|cab|FISH|-
graphics/account-pictures/frog.bmp|075adc45d321bd8b0562bd8df87febe1c0991224b9d00363550a7345de8522db|cab|FROG|-
graphics/account-pictures/guest.bmp|a1030522425b3258e21b3fd2a1dbafef2ed07154142dead7e9b7f4ae667c8726|cab|GUEST|-
graphics/account-pictures/guitar.bmp|07d3aeca5d09371344e66abd6cdf2151d2f05d84a568d31307bec54ef850600c|cab|GUITAR|-
graphics/account-pictures/horses.bmp|46f556f484064bb3cc55694c4fca9344b1432ac341861e56bac17d15cca46c7c|cab|HORSES|-
graphics/account-pictures/kick.bmp|66e1cd26c61f27567c02fcce0e757acc75a0afac1bca6d646b7b5aad69a86517|cab|KICK|-
graphics/account-pictures/lift-off.bmp|66cb10ca453d7e731070da923a0f9a767f0742a4c50b0b3cc04b42e43104fa46|cab|LIFTOFF|-
graphics/account-pictures/palm-tree.bmp|1d8a8607dd5b6aa413649cd3dc7187497e6a7fcb616e56c980fcfb682ee8c363|cab|PALMTREE|-
graphics/account-pictures/pink-flower.bmp|38d399a8fac9a3326370dcdfaad5c0de203883557f82d8373f0ce4ef7137a859|cab|PNKFLOWR|-
graphics/account-pictures/red-flower.bmp|4dc0a8afbf4dbb1a67b9292bb028b7f744f3029b0083c36307b1f84a00692a89|cab|REDFLOWR|-
graphics/account-pictures/skater.bmp|67a4ceda66f3abe6e0d18b08351d09c00e29f6a2ae3e55ad5e721218d6e45137|cab|SKATER|-
graphics/account-pictures/snowflake.bmp|9074d2d9e945ad6999ea143b7ed0a3d0007ed71c2fd6703253ccbdf5238ed889|cab|SNWFLAKE|-
graphics/account-pictures/ball.bmp|ac791b7dd63587134076d1b62f91de3710266be921b04f89c0ac4840d6531ef4|cab|SOCCER|-
binaries/luna.msstyles|dd8e86e5a7c19ea9fe0e34992babefe592055d68eb8659763c8300558ca5dcb4|cab|LUNA|-
binaries/ntoskrnl.exe|6005a1a1db35481612ef76856a609954990f058bfc42dfa7b0d43402bf3f3dcf|cab|NTOSKRNL|-
binaries/explorer.exe|1e675cb7df214172f7eb0497f7275556038a0d09c6e5a3e6862c5e26885ef455|cab|EXPLORER|-
binaries/logonui.exe|032b6d1f541f180a2fe619664ef180d3fd748aef7e311ba925fced74e7ed4713|cab|LOGONUI|-
binaries/msgina.dll|651b16027b4f4b0ed2f827e32b7e66188cdb023db8c7b1a9a1a44063fb35b9de|cab|MSGINA|-
binaries/shell32.dll|7c201e812138e2b9cbc2aa94e41d5573775d893b8104833a997acc79486d9a3a|cab|SHELL32|-
binaries/user32.dll|acd0ae7b4d5f871e148276c6cc4ae3a216e33f67fc78d827c16986e1f945438c|cab|USER32|-
binaries/stobject.dll|670006280ca98213c3a23b442615fd729c83953795619360f9d2988e56a602d7|cab|STOBJECT|-
binaries/batmeter.dll|76f8ae2680438b279081edfc2728e3785736e82a5c6396aa705bffff5c361294|cab|BATMETER|-
binaries/netshell.dll|3c0bfa381cbc2c55b58a8942a7148a6c27e244d26313efb4708dd5858c689e02|cab|NETSHELL|-
binaries/wuauclt.exe|20524aa4a86a4de282d304cbfad66b9e70d3f3baae828208a28f86e6ac521bdb|cab|WUAUCLT|-
binaries/mmsys.cpl|bb9b488afc5eb0a7137a03ab0757c48261581797b8ee6a9c889c01f13eb3dfaf|cab|MMSYS|-
binaries/desk.cpl|1fb5abae69103bf477f704189d75b0395f587234bfe94f9f79961d8fe2ce55ac|cab|DESK|-
binaries/powercfg.cpl|047cfe207d031983ba6f86aa2a131c2187ee616738bd017fcd63bc887f4b425a|cab|POWERCFG|-
binaries/agentsvr.exe|7a8fa00e694d713a128802221815fcb114999a392851c72c02a73564f1d95844|cab|AGENTSVR|-
binaries/fsquirt.exe|8f7e68ae96c36c434e8c6290e55c79c51d7032bcbebab742cf1013be8db54ba2|cab|FSQUIRT|-
binaries/xpsp2res.dll|dea7c556ba9c91e056e6035e77a793a77e428d493518d1c6f796b003d4f07305|cab|XPSP2RES|-
binaries/themeui.dll|f377590227e3bfc356996524ae2ff99b3eceffbc163f6ad9503b8aad24aecdb3|cab|THEMEUI|-
binaries/timedate.cpl|ca5d2f90158313d7b827c88c0d950e95366ed2bccc5e0503268c12be8e5d48ce|cab|TIMEDATE|-
binaries/sndvol32.exe|760fbbecef10ebe18aa84b1eddbc2237efb914c29a4413fb3cb6a7c60759b4f6|cab|SNDVOL32|-
binaries/input.dll|79a2b99effcb52b3edc840b452f629031656abd8632ee515ddeccbde487c3039|cab|INPUT|-
binaries/msctf.dll|2e7a7c08b56e07d69cb32f335d93f6d2c748efa2cf4c41102a18c7761a4e9cf0|cab|MSCTF|-
binaries/royale.msstyles|36779612b73904adfb28b626c5f401a7e82acbbb5232c49b7307922546de33ee|cab|@binaries/royale-installer.exe|Resources/Themes/Royale/Royale.msstyles
binaries/zune.msstyles|c95af747cc1b3aa47756cda32b06c926da8fe0c5b852184efdd25ae317b63a69|7z|ZUNEMSI|ZuneMSSTYLES
graphics/luna|968a16dd9ab6e175de13b330943c6dcbfd257e2c39446417046f6ad440ba70ab|peres|@binaries/luna.msstyles|BITMAP,TEXTFILE
graphics/royale|27f99dcc4662a7a061246a07d780d6c7fffa732b22570e84e395a69b7b0be2a3|peres|@binaries/royale.msstyles|BITMAP,TEXTFILE
graphics/zune|b0086fa438c6ca457ac26666d4ac4b6bc6547435539b61e5b4c36d6a0038d93e|peres|@binaries/zune.msstyles|BITMAP,TEXTFILE
graphics/ntoskrnl|3e2b0fdd4da641e723c74a10acc8e2f6b62687437abd593bac2ada3dd19877a6|peres|@binaries/ntoskrnl.exe|BITMAP
graphics/explorer|91b9af5a448b18941400481fe2f2a3f4ab3b5be8cd27e0a3efefc4970ba6f0f5|peres|@binaries/explorer.exe|BITMAP
graphics/logonui|134b298c0d752a846ec07d51d431f37992e3b277b80467e9b97ba8dc46fd2de1|peres|@binaries/logonui.exe|BITMAP
graphics/batmeter|b124e6c18e1eba1b7101678ba9fdaaff68641f965282ebde0a69480c450cfa90|strip|@binaries/batmeter.dll|300:32:ff00ff
graphics/msgina|cc31359b2187507b01afa5405a1c67974962405596577018bddebebdb998b985|peres|@binaries/msgina.dll|BITMAP
graphics/shell32-bmp|643f317d71a6a9ca8f55e28b1e153ac19cc3166bf8180cab609de0a7e234179e|peres|@binaries/shell32.dll|BITMAP
graphics/timedate-bmp|96d3598bccbf3f66b42194a44120bbd1875eba55f6034d3666cbf9a67e24fb02|peres|@binaries/timedate.cpl|BITMAP
graphics/themeui-bmp|7d47377c058e7a9c45d2f67716ae3efbf07d6f267ae789ab2b1975cf6ae5b14c|peres|@binaries/themeui.dll|BITMAP
graphics/shell32-ico|7c7698d3282408ada88753f74d33d606b395083c416cb81b3ef03b74ef45f76a|icons|@binaries/shell32.dll|16,32,48
graphics/user32-ico|4ac8bbda8868ea134356c2fdc0188fb3dd181c3242a73dc03bf68f9ac7ea0554|icons|@binaries/user32.dll|16,32,48
graphics/stobject-ico|369261852d99844eb2a4223e4a441b813eca0dddbceabe1ae1bfac8437b337aa|icons|@binaries/stobject.dll|16,32,48
graphics/netshell-ico|58766159d73e99336f435770b9fbb32bd2e640f6173c3d1658af95934d31c116|icons|@binaries/netshell.dll|16,32,48
graphics/wuauclt-ico|c8e7346032686373124b548e7daa46a947f6ff82d6fa4fe4bd355fd728d9bfed|icons|@binaries/wuauclt.exe|16,32,48
graphics/mmsys-ico|ecf75c3b04db6e043d63c524601008ed675615f4cbd25a77e7c778b4b618f4f5|icons|@binaries/mmsys.cpl|16,32,48
graphics/desk-ico|072e3d0ea00f36ee51b1f368cc7ca0ac255f4669297e2219e3612656a9ef12e4|icons|@binaries/desk.cpl|16,32,48
graphics/powercfg-ico|9ae8701bcaaf026719190979f06d8f55b058663f3bacc9865e61c1d06a18ae58|icons|@binaries/powercfg.cpl|16,32,48
graphics/agentsvr-ico|00e1d87fdbe99746162633e9fdc6ed0be4f3708248b8e02fcdd909f8f45d071a|icons|@binaries/agentsvr.exe|16,32,48
graphics/fsquirt-ico|2616948dacd02849964fd1041222a8dfccf40cfc74d063d8bcde96de92d2417c|icons|@binaries/fsquirt.exe|16,32,48
graphics/xpsp2res-ico|f1a291acb2fbfda024d0d2ff612183be34f075db50fe7338597166af7653d51f|icons|@binaries/xpsp2res.dll|16,32,48
graphics/timedate-ico|0b043ab1d98e80e8a6d9f038c0b3eee55f314e48aeec7f6d08245f9fe1dd37ec|icons|@binaries/timedate.cpl|16,32,48
graphics/sndvol32-ico|c69a562947b8159785ffb45a760a5fe7ebf9683e141f9f078bf76f2ef6cbf806|icons|@binaries/sndvol32.exe|16,32,48
graphics/input-ico|65ff25c7d0b5832e525f5fe69b80be5929bc1d13ae671372b611b885c4ee7b97|icons|@binaries/input.dll|16,32,48
graphics/msctf-ico|78787fd8a9393e03dbbbc29baab9df539a7b09ce672db614a9881934ae55f6bf|icons|@binaries/msctf.dll|16,32,48
graphics/boot/boot-screen.bmp|0dd5789a62c486c593c2eeded0e14043229cb74fd27e738e957270326b593d69|bootpal|@binaries/ntoskrnl.exe|1
graphics/boot/progress-segment.bmp|f8f9a140d5624f81bc778ebef9bed1299248a86c89e64b9bc7f2b223149d1904|bootpal|@binaries/ntoskrnl.exe|8
graphics/boot/safe-to-turn-off-text.bmp|f244c0db682acdfd121d6f8eb8adc2cc04b957b4205649ab50e2c33a1bf8fbbe|bootpal|@binaries/ntoskrnl.exe|3
reference/boot-screen-xp-professional.png|6fb6c4cc953f0c721c7e48656f15008c0f5c132b76540eb239ecea3198c1e841|raw|R_BOOT|-
reference/logon-welcome-to-windows-dialog.png|cd049bfeb497de49b8e93c0285da218bfdf2a77aaf6dca77a11335c9bd464584|raw|R_LOGIN|-
reference/desktop-luna-blue.png|55c204cee4bdede24dcae87217c9e2fc3d1e255b55a78b09cbf3eec97944fcc4|raw|R_LUNA|-
reference/desktop-olive-green.png|fdbce99dd98eeaa81622a5c9fad2e6b7e979aefe61e9d9ea8033c36310ee0caf|raw|R_OLIVE|-
reference/desktop-silver.png|4373a4ea6cf36af82f32a400999cd812e5c5d60da6f1240e8f5b7b28bbb83d18|raw|R_SILVER|-
reference/desktop-royale.png|870d5cda51641ba7f878f54b94f8ce60e2eea26b9b4c40e37cac216d6c951f28|raw|R_ROYALE|-
reference/desktop-zune.png|134109839b2db8fbf7dd3a69010faafbae94bae49880bef00c16b1aba700e152|raw|R_ZUNE|-
reference/desktop-royale-media-center.png|6ba7ab9b5cd092abed5e38bd8344efd43c9025204195e893102b98b11fa9768a|raw|R_MCE|-
reference/taskbar-luna-blue-1920x974.png|4b87922d3f7c2622108a59538c7983769125917a090f5210f0ef17f6ea3af7ef|raw|R_X64BLUE|-
reference/taskbar-olive-green-1920x974.png|8c61216858e67be2319c9902ff04015f0334f796142466195fe0b1e5d68e56df|raw|R_X64OLIVE|-
reference/taskbar-silver-1920x974.png|dec835bb78a9b014ab9407fb8c5b534e6770fdf64c82f418d7e20aa2b751b226|raw|R_X64SILVER|-
reference/start-menu-luna-blue.png|3d68ed49a9d240218bcb96eefc86b4da6dddeba7046350c087aa6f0d1bb267e5|raw|R_START|-
reference/start-menu-royale.png|e950aaa21720bacee22be6dd2852c16dab1b9cf9ce46c808769bebcf2a6a9925|raw|R_STARTROYALE|-
reference/taskbar-grouping-luna-blue.png|ca1ba795898d0e2e414695befbd3766792204f29e21b481a7077a2df7ba090ea|raw|R_GROUPING|-
reference/turn-off-computer-dialog.png|0200c1fc660f155d2f7b611c66291826435b10ddfee01c5d2e4f6c7bcaf8208e|raw|R_TURNOFF|-
reference/cmd-exe-ipconfig.png|cb8b859063327f946452f357770ea96c4f439ff4b7600a9bd3c1dbd83311bb65|raw|R_CMD|-
reference/cmd-exe-banner.png|b37068ef0c4f0b20d9aaed0dc01df60ef400d43741ac207627f767460b9660bc|raw|R_CMDBANNER|-
reference/task-manager.png|12c9fcf308097700f8238315ab78aed0963bdd6b6473021ce0d24d707ac78f3f|raw|R_TASKMGR|-
reference/dialog-automatic-updates.png|53b5835d3d27c564f91af3ef8b4079ef5be991ec3b02c7c5d1e0b0e87f85f9d1|raw|R_AUTOUPD|-
reference/search-companion.png|3db280beb3f28dcb4d5b81c1280cabfe7aa215ed45b4c92c610c6046be06b6e6|raw|R_SEARCHCOMP|-
reference/explorer-task-pane.png|a21830d48ffdae542159e0e83c286942c99ba8b764363ee86cea28f8c0fc3c7d|raw|R_EXPLORER|-
reference/hivedef.inf|00efcf4da1f58f7798b2a48001b1699ade27753698725056f8e0dbb7135e5189|raw|HIVEDEF|-
gtk/Windows XP Luna|dd3b71d1f15e7ec0f2b6a6fee9695e7a0f272af3f8bf82dd57d05a7b02657742|zip|XPGTK|Windows-XP-7637830906823af40a3cd7e7079be753d8b7d679/Windows XP Luna
gtk/Windows XP Homestead|56be1012e131d5b0a822d9cc67de8a1d946a78403ecb02b83d59f57286284668|zip|XPGTK|Windows-XP-7637830906823af40a3cd7e7079be753d8b7d679/Windows XP Homestead
gtk/Windows XP Metallic|3e8140d9ec1564083975f70bbb9963f903d1ed2bdd3532c7cea282657de26487|zip|XPGTK|Windows-XP-7637830906823af40a3cd7e7079be753d8b7d679/Windows XP Metallic
gtk/Windows XP Royale|f94694b90dbb370e481a82201cd1ab2d5c3e364dbc1a6e3a850bee130e85809e|zip|XPGTK|Windows-XP-7637830906823af40a3cd7e7079be753d8b7d679/Windows XP Royale
gtk/Windows XP Zune|258ba6b939643019c43d902c5733616afced5cd318a901be28be273b0660d44d|zip|XPGTK|Windows-XP-7637830906823af40a3cd7e7079be753d8b7d679/Windows XP Zune
icons/windows-xp-base|34953c07cf269b49157418b04ce1ca8f678ab893e9a60b2b610af4adf0022161|zip|XPICONS|Windows-XP-24e95ad2b12c55dd11883ee7066525527d944039
icons/windows-xp-cursors|cc0e8343dea95e48b417ef1974fa7ffb274330bdb74d8b9f877570a7292e6810|xcursor|@binaries/user32.dll|-
EOF
)

declare -A SRC_SHA SRC_URL
while IFS='|' read -r key sha url; do
    SRC_SHA[$key]=$sha SRC_URL[$key]=$url
done <<<"$SOURCES"

failures=() verified=0
err() { echo "  error: $*" >&2; }

hash_of() {  # file -> sha256; directory -> sha256 of its sorted per-file sha256 list
    # plus its sorted "link -> target" list (empty for trees without links,
    # so the older directory pins are unchanged)
    if [[ -d $1 ]]; then
        (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
         find . -type l -printf '%p -> %l\n' | LC_ALL=C sort) | sha256sum | cut -d' ' -f1
    elif [[ -f $1 ]]; then
        sha256sum "$1" | cut -d' ' -f1
    fi
}

fetch_source() {  # key -> path of the verified download (cached for this run)
    local key=$1 out=$WORK/src/$1
    [[ -f $out ]] && { echo "$out"; return; }
    [[ -n ${SRC_URL[$key]:-} ]] || { err "unknown source $key"; return 1; }
    echo "  downloading $key" >&2
    if ! curl -fsSL --retry 4 --retry-delay 10 -m 600 -A "$UA" -o "$out.part" "${SRC_URL[$key]}"; then
        err "download failed: $key ${SRC_URL[$key]}"; rm -f "$out.part"; return 1
    fi
    [[ ${SRC_URL[$key]} == *upload.wikimedia.org* ]] && sleep 3  # Wikimedia rate-limits bursts
    echo "$key" >>"$WORK/downloaded"
    local got; got=$(hash_of "$out.part")
    if [[ $got != "${SRC_SHA[$key]}" ]]; then
        err "HASH MISMATCH source $key: expected ${SRC_SHA[$key]} got $got"
        rm -f "$out.part"; return 1
    fi
    mv "$out.part" "$out"; echo "$out"
}

input_path() {  # source key or @assets-relative path -> local file
    if [[ $1 == @* ]]; then
        local p=$ASSETS/${1#@}
        [[ -f $p ]] || { err "missing input $1"; return 1; }
        echo "$p"
    else
        fetch_source "$1"
    fi
}

pick() {  # dir member -> the extracted file
    local d=$1 m=$2
    if [[ $m == - ]]; then
        local files=("$d"/*)
        ((${#files[@]} == 1)) && [[ -f ${files[0]} ]] || { err "expected one file in archive"; return 1; }
        echo "${files[0]}"
    else
        [[ -f $d/$m || -d $d/$m ]] || { err "member not found: $m"; return 1; }
        echo "$d/$m"
    fi
}

build() {  # method src member -> path of the produced file/dir (inside $WORK)
    local method=$1 src=$2 member=$3 in x
    in=$(input_path "$src") || return 1
    x=$(mktemp -d "$WORK/x.XXXXXX")  # fresh, empty extraction directory
    case $method in
        raw) echo "$in" ;;
        cab) cabextract -q -d "$x" "$in" >/dev/null 2>&1 || { err "cabextract failed: $src"; return 1; }; pick "$x" "$member" ;;
        7z) 7z x -y -o"$x" "$in" >/dev/null || { err "7z failed: $src"; return 1; }; pick "$x" "$member" ;;
        zip) bsdtar -xf "$in" -C "$x" || { err "bsdtar failed: $src"; return 1; }; pick "$x" "$member" ;;
        peres) python3 -I "$WORK/xptool.py" peres "$in" "$x/out" "$member" || { err "peres failed: $src"; return 1; }; echo "$x/out" ;;
        icons) python3 -I "$WORK/xptool.py" icons "$in" "$x/out" "$member" || { err "icons failed: $src"; return 1; }; echo "$x/out" ;;
        xcursor) python3 -I "$WORK/xptool.py" xcursor "$in" "$x/out" || { err "xcursor failed: $src"; return 1; }; echo "$x/out" ;;
        strip) python3 -I "$WORK/xptool.py" strip "$in" "$x/out" "$member" || { err "strip failed: $src"; return 1; }; echo "$x/out" ;;
        bootpal)
            python3 -I "$WORK/xptool.py" peres "$in" "$x/res" BITMAP || { err "peres failed: $src"; return 1; }
            python3 -I "$WORK/xptool.py" bootpal "$x/res/BITMAP/$member.bmp" "$x/out.bmp" || { err "bootpal failed"; return 1; }
            echo "$x/out.bmp" ;;
        *) err "unknown method $method"; return 1 ;;
    esac
}

while IFS='|' read -r dest sha method src member; do
    target=$ASSETS/$dest
    if [[ -e $target && $(hash_of "$target") == "$sha" ]]; then
        verified=$((verified + 1)); continue
    fi
    [[ -e $target ]] && echo "  stale or modified, rebuilding: $dest"
    echo "fetch: $dest"
    produced=$(build "$method" "$src" "$member") || { failures+=("not installed: $dest (see error above)"); continue; }
    if [[ -d $produced ]] && escaped=$(find "$produced" -type l -print0 | xargs -0 -r realpath -m -- | grep -v "^$produced/"); then
        failures+=("$dest: symlinks leave the tree: $escaped"); continue
    fi
    got=$(hash_of "$produced")
    if [[ $got != "$sha" ]]; then
        failures+=("HASH MISMATCH $dest: expected $sha got $got"); continue
    fi
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    if [[ $method == raw ]]; then cp "$produced" "$target"; else mv "$produced" "$target"; fi
    chmod -R u+rwX,go+rX,go-w "$target"
    verified=$((verified + 1))
done <<<"$OUTPUTS"

# ── Fonts → ~/.local/share/fonts/xp, refresh fontconfig only on change ───────
fonts_changed=0
mkdir -p "$FONTDIR"
for f in "$ASSETS"/fonts/*.ttf; do
    [[ -f $f ]] || continue
    if ! cmp -s "$f" "$FONTDIR/$(basename "$f")"; then
        install -m 644 "$f" "$FONTDIR/"; fonts_changed=1
    fi
done
if ((fonts_changed)); then
    fc-cache -f "$FONTDIR" && echo "fonts: installed to $FONTDIR, fc-cache refreshed"
else
    echo "fonts: up to date in $FONTDIR"
fi

# ── Theme backgrounds → omarchy/themes/windows-xp*/backgrounds (hard links) ──
# Hard links, not symlinks: omarchy-theme-bg-set stores the *realpath* of the
# image while omarchy-theme-bg-next looks the current one up by its unresolved
# path, so with symlinks `omarchy theme bg next` sticks on the first image.
# Hard links cost no space here and `cp -r` turns them into real files in the
# theme state dir. Backgrounds cycle in sorted order, so each scheme's default
# gets a 00- prefix. Names carry the theme slug: theme-set starts on "the one
# after the current background" when the name matches, so shared names would
# make an XP-to-XP switch skip the scheme's default. Low-res duplicates
# (bliss/autumn/zune.jpg) are skipped.
WALLS=(bliss-4510x3627.png autumn-4200x2800.jpg ascent.jpg azul.jpg crystal.jpg
    follow.jpg friend.jpg home.jpg moon-flower.jpg peace.jpg power.jpg
    purple-flower.jpg radiance.jpg red-moon-desert.jpg ripple.jpg
    royale-energy-bliss.jpg stonehenge.jpg tulips.jpg vortec-space.jpg wind.jpg
    windows-xp.jpg zune-widescreen-1900x1200.jpg)
links_changed=0
for spec in windows-xp:bliss-4510x3627.png windows-xp-olive:autumn-4200x2800.jpg \
            windows-xp-silver:ascent.jpg windows-xp-royale:royale-energy-bliss.jpg \
            windows-xp-zune:zune-widescreen-1900x1200.jpg; do
    bgdir=$(dirname "$HERE")/themes/${spec%%:*}/backgrounds
    mkdir -p "$bgdir"
    for w in "${WALLS[@]}"; do
        [[ -f $ASSETS/wallpapers/$w ]] || continue
        link=$bgdir/${spec%%:*}-$w; [[ $w == "${spec#*:}" ]] && link=$bgdir/00-${spec%%:*}-$w
        [[ ! -L $link && $link -ef $ASSETS/wallpapers/$w ]] && continue
        ln -f "$ASSETS/wallpapers/$w" "$link"; links_changed=$((links_changed + 1))
    done
done
echo "backgrounds: $links_changed theme links (re)created"

# ── Taskbar art (ocko.xp-taskbar) → assets/graphics/taskbar/<slug>/*.png ──
"$HERE/bin/xp-taskbar-art" || failures+=("taskbar art")

# ── XP About / screensaver text → assets/branding (xp-mode swaps them in) ────
# The boot screen's logo (flag, "Microsoft Windows xp") as terminal art:
# truecolor half-blocks for fastfetch's About logo, mono for the stock ttfx
# screensaver. Derived from Microsoft's bitmap, so it stays in assets/.
mkdir -p "$ASSETS/branding"
for spec in about.txt:64:color screensaver.txt:72:mono; do
    IFS=: read -r name cols mode <<<"$spec"
    magick "$ASSETS/graphics/boot/boot-screen.bmp" -crop 256x156+204+118 +repage \
        -filter box -resize "${cols}x" -depth 8 "$WORK/logo.ppm" &&
        python3 -I "$WORK/xptool.py" halfblock "$WORK/logo.ppm" "$WORK/$name" "$mode" &&
        { cmp -s "$WORK/$name" "$ASSETS/branding/$name" || cp "$WORK/$name" "$ASSETS/branding/$name"; } ||
        failures+=("branding $name")
done

# ── GTK, icon and cursor themes → ~/.local/share/{themes,icons} (Task 9) ─────
# Copied rather than linked so the desktop never reads assets/; a .xp-src stamp
# holding the pinned tree hash makes reruns no-ops. Uninstall: ASSETS.md.
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
install_tree() {  # assets-relative src, destination dir
    [[ -d $ASSETS/$1 ]] || { failures+=("not installed: $2 ($1 missing)"); return; }
    local sha; sha=$(hash_of "$ASSETS/$1")
    [[ -r $2/.xp-src && $(<"$2/.xp-src") == "$sha" ]] && return
    mkdir -p "$(dirname "$2")" && rm -rf "$2.xp-tmp" && cp -r "$ASSETS/$1" "$2.xp-tmp" &&
        echo "$sha" >"$2.xp-tmp/.xp-src" && rm -rf "$2" && mv "$2.xp-tmp" "$2" &&
        echo "installed: $2" || failures+=("install $2")
}
for t in Luna Homestead Metallic Royale Zune; do
    install_tree "gtk/Windows XP $t" "$DATA/themes/Windows XP $t"
done
install_tree icons/windows-xp-base "$DATA/icons/windows-xp-base"
install_tree icons/windows-xp-cursors "$DATA/icons/windows-xp-cursors"
# No icon cache: upstream's .icon-theme.cache is stale, and gtk-update-icon-cache
# rejects this tree ("The generated cache was invalid"), so GTK scans the dirs.
rm -f "$DATA/icons/windows-xp-base/.icon-theme.cache"

# "windows-xp", the icon theme the XP themes' icons.theme names: XP's own
# shell32/user32 icons (16/32/48, PNGs from xp-taskbar-art) for the places,
# devices and dialogs people actually see, inheriting the B00merang set for
# everything else and Adwaita for what that lacks. shell32 ids were checked on
# a contact sheet (ASSETS.md).
XP_ICONS=(shell32:4:folder,inode-directory shell32:5:folder-open shell32:235:user-home,folder-documents
    shell32:236:folder-pictures shell32:237:folder-music shell32:238:folder-videos shell32:35:user-desktop
    shell32:32:user-trash shell32:33:user-trash-full shell32:18:network-workgroup shell32:16:computer
    shell32:9:drive-harddisk shell32:8:drive-removable-media shell32:12:drive-optical shell32:17:printer
    shell32:23:system-search shell32:25:system-run shell32:28:system-shutdown shell32:45:system-log-out
    shell32:48:system-lock-screen shell32:24:help-browser shell32:14:web-browser
    shell32:36:preferences-system shell32:152:text-x-generic shell32:1:application-x-generic
    user32:101:dialog-warning user32:102:dialog-question user32:103:dialog-error user32:104:dialog-information)
wrap=$WORK/icons-windows-xp
mkdir -p "$wrap"
printf '%s\n' '[Icon Theme]' 'Name=Windows XP (Omarchy)' \
    "Comment=XP's own shell32/user32 icons over the B00merang Windows XP set" \
    'Inherits=windows-xp-base,Adwaita,hicolor' 'Directories=16x16/xp,32x32/xp,48x48/xp' >"$wrap/index.theme"
for s in 16 32 48; do
    printf '\n[%sx%s/xp]\nSize=%s\nType=Fixed\n' "$s" "$s" "$s" >>"$wrap/index.theme"
    mkdir -p "$wrap/${s}x$s/xp"
    for spec in "${XP_ICONS[@]}"; do
        IFS=: read -r lib id names <<<"$spec"
        png=$ASSETS/graphics/$lib/$s/$id.png
        [[ -f $png ]] || continue  # not every group has every size (36 has no 48 px); GTK scales
        for n in ${names//,/ }; do cp "$png" "$wrap/${s}x$s/xp/$n.png"; done
    done
done
if ! diff -rq "$wrap" "$DATA/icons/windows-xp" >/dev/null 2>&1; then
    rm -rf "$DATA/icons/windows-xp" && cp -r "$wrap" "$DATA/icons/windows-xp" &&
        echo "installed: $DATA/icons/windows-xp" ||
        failures+=("install $DATA/icons/windows-xp")
fi

downloaded=0
[[ -f $WORK/downloaded ]] && downloaded=$(wc -l <"$WORK/downloaded")
echo "fetch-assets: $verified verified, $downloaded downloaded, ${#failures[@]} failed"
if ((${#failures[@]})); then
    printf '  FAIL: %s\n' "${failures[@]}" >&2
    exit 1
fi
