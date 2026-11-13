#!/bin/bash
# install.sh [--dry-run] -- install the Windows XP theme into this user's
# Omarchy. Re-runnable: `git pull && ./install.sh` updates in place.
#
#   --dry-run  print every action and, for each edit to one of your own files,
#              the diff it would make; change nothing (no packages, no sudo, no
#              systemd, no theme switch, no downloads).
#
# Run it as yourself. It asks for sudo only for missing packages (pacman) and,
# only if you say yes at the end, for the boot splash. Nothing from the AUR.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PAYLOAD=$HERE/payload
CFG=$HOME/.config
XP=$CFG/omarchy/xp
MARKER=$XP/.omarchy-windows-xp
BEGIN='# >>> omarchy-windows-xp'
END='# <<< omarchy-windows-xp'
STOCK=${OMARCHY_PATH:-/usr/share/omarchy}/config
DRY=0
case ${1:-} in
  --dry-run) DRY=1 ;;
  "") ;;
  *) echo "usage: ./install.sh [--dry-run]" >&2; exit 2 ;;
esac

say() { printf '\n== %s\n' "$*"; }
warn() { printf 'install.sh: %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }
# run: print a command, and run it unless this is a dry run.
run() { printf '+ %s\n' "$*"; ((DRY)) || "$@"; }

# ------------------------------------------------------------------ pre-flight
say "Pre-flight"
((EUID != 0)) || die "run this as yourself, not root; it asks for sudo itself"
command -v omarchy >/dev/null && [[ -d ${OMARCHY_PATH:-/usr/share/omarchy} ]] || die "Omarchy not found"
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || ! command -v hyprctl >/dev/null; then die "run this inside a Hyprland session"; fi
command -v foot >/dev/null || die "foot (Omarchy's terminal) not found"
echo "Omarchy $(omarchy version 2>/dev/null || echo '?'), $(hyprctl version -j | jq -r '"Hyprland " + .tag')"

# Title bars: our own user-level build of hyprbars with the XP caption buttons
# (omarchy/xp/hyprbars/build). It needs the Hyprland headers of the *running*
# Hyprland and nothing from the AUR. The AUR package is not installed from
# here: yay compiles it against the same headers, so it could only load where
# this build already works, and the AUR moves to the next Hyprland before Arch
# does (0.57.0 while Arch shipped 0.56.2), so `yay -S` would try to install a
# plugin the running Hyprland refuses.
TITLEBARS=1
hv=$(hyprctl version -j | jq -r .tag)
hc=$(hyprctl version -j | jq -r .commit)
if [[ $hv != v0.56.* ]]; then
  TITLEBARS=0
  warn "Hyprland is $hv: the XP caption-button patch targets 0.56.x, so XP title bars are skipped. Everything else installs."
fi

echo "Compatibility of each XP part with this Omarchy (failing parts fall back to stock):"
python3 "$PAYLOAD/omarchy/xp/bin/xp-compat-test" --plugins "$PAYLOAD/omarchy/plugins" | sed 's/^/  /'

# Every path this package installs. A path that already exists must be ours
# from an earlier run (the marker), or the install refuses to touch it.
targets=("$XP" "$CFG/systemd/user/xp-sizes.path" "$CFG/systemd/user/xp-sizes.service")
for d in "$PAYLOAD"/omarchy/themes/* "$PAYLOAD"/omarchy/plugins/*; do targets+=("$CFG/omarchy/${d#"$PAYLOAD"/omarchy/}"); done
while IFS= read -r f; do targets+=("$CFG/omarchy/${f#"$PAYLOAD"/omarchy/}"); done < <(find "$PAYLOAD/omarchy/hooks" -type f)
foreign=()
for t in "${targets[@]}"; do
  [[ -e $t || -L $t ]] || continue
  if [[ ! -e $MARKER ]]; then
    foreign+=("$t")
  elif [[ $t == "$CFG"/omarchy/plugins/* ]] &&
    [[ $(jq -r '.id + " " + .author' "$t/manifest.json" 2>/dev/null) != "${t##*/} ocko" ]]; then
    foreign+=("$t (manifest is not this package's ${t##*/})")
  fi
done
if ((${#foreign[@]})); then
  printf '  not from this package: %s\n' "${foreign[@]}" >&2
  die "refusing to overwrite the files above; move them aside and re-run"
fi
echo "Install targets: ${#targets[@]}, none foreign."

# ------------------------------------------------------------------- packages
say "Packages"
PKGS=(cabextract 7zip libarchive imagemagick jq python cmake gcc make pkgconf curl git xscreensaver)
# sudo only for what is missing, so a re-run with everything present needs no
# password (and works from a session without a terminal).
mapfile -t missing < <(pacman -T "${PKGS[@]}")
if ((${#missing[@]} == 0)); then
  echo "all present: ${PKGS[*]}"
elif ((!DRY)) && [[ ! -t 0 ]] && ! sudo -n true 2>/dev/null; then
  die "packages to install (${missing[*]}) need sudo, and there is no terminal to ask for the password: run ./install.sh from a terminal"
else
  run sudo pacman -S --needed "${missing[@]}" || die "pacman failed"
fi
if ((TITLEBARS)); then
  hdr=$(pkg-config --modversion hyprland 2>/dev/null)
  hdr_commit=$(sed -n 's/^#define GIT_COMMIT_HASH *"\(.*\)"/\1/p' /usr/include/hyprland/src/version.h 2>/dev/null)
  if [[ "v$hdr" != "$hv" || $hdr_commit != "$hc" ]]; then
    TITLEBARS=0
    warn "the Hyprland headers (v${hdr:-none}) are not the running Hyprland ($hv): log out and back in after the Hyprland update, then re-run. XP title bars are skipped until then."
  else
    echo "XP title bars: Hyprland $hv headers match, the caption-button build will run"
  fi
fi

# ---------------------------------------------------------------------- files
say "Files"
# Directories under omarchy/xp and the themes are overlaid, so what fetch-
# assets.sh generated there (assets/, theme backgrounds/) survives an update.
# Plugin directories are replaced whole, so a file dropped upstream goes too.
run mkdir -p "$CFG/omarchy/themes" "$CFG/omarchy/plugins" "$CFG/systemd/user"
run cp -a "$PAYLOAD/omarchy/xp/." "$XP/"
for d in "$PAYLOAD"/omarchy/themes/*; do run mkdir -p "$CFG/omarchy/themes/${d##*/}"; run cp -a "$d/." "$CFG/omarchy/themes/${d##*/}/"; done
for d in "$PAYLOAD"/omarchy/plugins/*; do run rm -rf "$CFG/omarchy/plugins/${d##*/}"; run cp -a "$d" "$CFG/omarchy/plugins/"; done
while IFS= read -r f; do
  rel=${f#"$PAYLOAD"/omarchy/}
  run mkdir -p "$(dirname "$CFG/omarchy/$rel")"
  run cp -a "$f" "$CFG/omarchy/$rel"
done < <(find "$PAYLOAD/omarchy/hooks" -type f)
# Files earlier versions installed that this one no longer has. The XP
# theme-set hook was split into 00-windows-xp-off (runs first) and
# zz-windows-xp-on (runs last); the old one would still run in between.
f=$CFG/omarchy/hooks/theme-set.d/windows-xp
if [[ -e $f ]]; then run rm -f "$f"; fi
run cp -a "$PAYLOAD/systemd/user/xp-sizes.path" "$PAYLOAD/systemd/user/xp-sizes.service" "$CFG/systemd/user/"
printf '+ write %s\n' "$MARKER"
((DRY)) || head -1 "$HERE/VERSION" >"$MARKER"
run systemctl --user daemon-reload
run systemctl --user enable --now xp-sizes.path

# ----------------------------------------------------------------- host edits
# Three of your own files get one marked block each, after a .pre-xp backup.
# A file that already has the block is left alone.
say "Edits to your own files"
# host_edit <file> <stock copy if the file is missing> <block> [<where>...]
#   where: after:<ERE> or before:<ERE>, tried in order; the block goes after /
#   before the first line matching ERE, and at the end if none matches.
# The block always gets exactly one blank line above it, which is what lets
# uninstall.sh take out "blank line + block" and restore the file exactly.
host_edit() {
  local file=$1 stock=$2 block=$3 tmp src w placed=0
  shift 3
  if [[ -e $file ]] && grep -qF "$BEGIN" "$file"; then
    echo "$file: already has the block, left alone"
    return 0
  fi
  src=$file
  if [[ ! -e $file ]]; then
    [[ -r $stock ]] || { warn "$file missing and no stock copy at $stock; skipped"; return 1; }
    src=$stock
    echo "$file: missing, created from $stock"
  fi
  tmp=$(mktemp)
  for w in "$@"; do
    grep -qE "${w#*:}" "$src" || continue
    # ENVIRON, not -v: awk -v would eat the backslashes in RE.
    RE=${w#*:} BLK=$block WHERE=${w%%:*} awk '
      !done && $0 ~ ENVIRON["RE"] {
        if (ENVIRON["WHERE"] == "after") print
        print ""; print ENVIRON["BLK"]; done = 1
        if (ENVIRON["WHERE"] == "after") next
      }
      { print }' "$src" >"$tmp"
    placed=1
    break
  done
  if ((!placed)); then
    (($#)) && warn "$file: no line matching ${*#*:}; block appended at the end"
    { cat "$src"; printf '\n%s\n' "$block"; } >"$tmp"
  fi
  diff -u --label "$file (now)" --label "$file (with XP)" "$src" "$tmp"
  if ((DRY)); then
    rm -f "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  [[ -e $file && ! -e $file.pre-xp ]] && cp -a "$file" "$file.pre-xp"
  cat "$tmp" >"$file" && rm -f "$tmp"
}

host_edit "$CFG/foot/foot.ini" "$STOCK/foot/foot.ini" "$BEGIN
# The theme's foot.ini again, last: later keys win, so the Windows XP themes
# can set the font, cursor and title. Other themes only set colours, which
# nothing above sets, so they look exactly as before.
[main]
include=~/.local/state/omarchy/current/theme/foot.ini
$END"

# Interactive shells only, and above Omarchy's bash init: right after the
# interactive guard, else just above the rc source.
host_edit "$HOME/.bashrc" /etc/skel/.bashrc "$BEGIN
# Windows XP theme: cmd.exe prompt and banner (a no-op under other themes).
# Above Omarchy's bash init, so starship sees STARSHIP_CONFIG when it starts.
[[ -r ~/.config/omarchy/xp/bashrc ]] && source ~/.config/omarchy/xp/bashrc
$END" 'after:^\[\[ \$- != \*i\* \]\] && return' 'before:^[[:space:]]*source .*default/bash/rc'

host_edit "$CFG/tmux/tmux.conf" "$STOCK/tmux/tmux.conf" "$BEGIN
# A theme may restyle the status bar with its own tmux.conf (the Windows XP
# themes do). Sourced last so it wins; -q makes a theme without one a no-op.
source-file -q ~/.local/state/omarchy/current/theme/tmux.conf
$END"

# ------------------------------------------------------- assets and binaries
say "Microsoft's files (downloaded here, never shipped) and derived art"
# fetch-assets.sh also runs xp-taskbar-art and installs the fonts, GTK, icon
# and cursor themes under ~/.local/share. Idempotent: reruns skip what is
# already there and verified.
run "$XP/fetch-assets.sh" || die "fetch-assets.sh failed (see above); nothing switched to XP yet. Re-run ./install.sh to retry."
if ((TITLEBARS)); then
  say "XP caption buttons (patched hyprbars, user-level)"
  BARS_LOG=$HOME/.local/state/omarchy/xp/hyprbars-build.log
  printf '+ %s >%s 2>&1\n' "$XP/hyprbars/build" "$BARS_LOG"
  if ((!DRY)); then
    mkdir -p "${BARS_LOG%/*}"
    if "$XP/hyprbars/build" >"$BARS_LOG" 2>&1; then
      tail -n 1 "$BARS_LOG"
    else
      warn "THE XP CAPTION-BUTTON BUILD FAILED; windows get plain title bars. Last lines of $BARS_LOG:"
      tail -n 15 "$BARS_LOG" | sed 's/^/    /' >&2
      warn "fix the cause above, then run: $XP/hyprbars/build && hyprctl reload"
    fi
  fi
fi

# ------------------------------------------------------------------- activate
say "Switch to Windows XP"
cur=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
scheme=windows-xp
[[ $cur == windows-xp-* ]] && scheme=$cur
run omarchy theme set "$scheme"

# ---------------------------------------------------------------- boot splash
say "Boot splash (optional)"
cat <<'EOF'
The XP boot screen also replaces the disk-password prompt with a "Log On to
Windows" dialog. If it ever misbehaves at boot: press Esc for the plain text
prompt (typing the password blind also works), or pick a Limine "Snapshots"
entry, then run:  ~/.config/omarchy/xp/bin/xp-boot off
EOF
fallback=0
[[ -r /boot/limine.conf ]] && grep -qE '^[[:space:]]*/+Snapshots' /boot/limine.conf && fallback=1
if ((!fallback)); then
  echo "No Limine snapshot entry found to fall back on, so the splash is not offered here."
  echo "Install it later yourself with: ~/.config/omarchy/xp/bin/xp-boot on"
elif ((DRY)); then
  echo "(dry run) would ask [y/N], then run: $XP/bin/xp-boot on"
else
  read -r -p "Install the XP boot splash now? It uses sudo and rebuilds the boot image. [y/N] " ans
  if [[ $ans == [yY] ]]; then run "$XP/bin/xp-boot" on || warn "xp-boot on failed; the stock splash is unchanged"; else echo "Skipped."; fi
fi

# ---------------------------------------------------------------- post-check
say "Check"
if ((DRY)); then
  echo "(dry run) would print: xp-mode status, hyprctl configerrors, the compatibility table, Tahoma in fc-list, the live XP terminal font line"
  exit 0
fi
"$XP/bin/xp-mode" status
echo "hyprctl configerrors: $(hyprctl configerrors | tr -s '\n' ' ')"
# The theme switch reloads Hyprland asynchronously: give the plugin a moment.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  bars=$(grep -o '[^ ]*\(hyprbars\|xpbars\|titlebars\)[^ ]*\.so' "/proc/$(pidof Hyprland)/maps" 2>/dev/null | sort -u | tr '\n' ' ')
  [[ $bars == *"$HOME/.local/lib/hyprbars-xp/"* ]] && break
  sleep 0.5
done
case $bars in
  *"$HOME/.local/lib/hyprbars-xp/"*) echo "title bars: XP caption buttons ($bars)" ;;
  "") warn "title bars: no hyprbars loaded in Hyprland" ;;
  *) warn "title bars: Hyprland has $bars, not the XP build: no XP title bars (see $HOME/.local/state/omarchy/xp/hyprbars-build.log)" ;;
esac
python3 "$XP/bin/xp-compat-test" | sed 's/^/  /'
fc-list : family | grep -i -m1 tahoma || warn "Tahoma is not installed (fetch-assets.sh)"
grep -m1 '^font=' "$HOME/.local/state/omarchy/current/theme/foot.ini"
cat <<'EOF'

Done. Open a new terminal to see the XP console (running ones keep their font).
If you installed the boot splash, reboot once to see it.
EOF
