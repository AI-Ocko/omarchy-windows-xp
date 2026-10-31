#!/bin/bash
# uninstall.sh [--dry-run] -- remove everything install.sh added, from this
# user's account. Packages and the boot splash need sudo, so for those it only
# prints the commands to run yourself.
#
#   --dry-run  print every action and the edit to each of your own files;
#              change nothing.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PAYLOAD=$HERE/payload
CFG=$HOME/.config
XP=$CFG/omarchy/xp
MARKER=$XP/.omarchy-windows-xp
BEGIN='# >>> omarchy-windows-xp'
END='# <<< omarchy-windows-xp'
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
DRY=0
case ${1:-} in
  --dry-run) DRY=1 ;;
  "") ;;
  *) echo "usage: ./uninstall.sh [--dry-run]" >&2; exit 2 ;;
esac

say() { printf '\n== %s\n' "$*"; }
warn() { printf 'uninstall.sh: %s\n' "$*" >&2; }
run() { printf '+ %s\n' "$*"; ((DRY)) || "$@"; }
# remove: rm -rf each path that exists; list the absent ones too.
remove() {
  local p
  for p in "$@"; do
    if [[ -e $p || -L $p ]]; then run rm -rf -- "$p"; else printf '  (absent) %s\n' "$p"; fi
  done
}

((EUID != 0)) || { warn "run this as yourself, not root"; exit 1; }
if [[ ! -e $MARKER ]]; then
  ((DRY)) || { warn "no $MARKER: this package is not installed here (or this is a source checkout); nothing removed"; exit 1; }
  warn "no $MARKER: a real run would stop here; listing what it would do anyway"
fi

# 1. Leave XP the normal way first: a non-XP theme runs `xp-mode off`, which
#    restores gsettings, shell.json, the swapped files and the Hyprland toggle.
say "Theme"
cur=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
if [[ $cur == windows-xp || $cur == windows-xp-* ]]; then
  run omarchy theme set tokyo-night
else
  echo "current theme is ${cur:-unknown}, not XP: nothing to switch"
fi

say "Systemd user units"
run systemctl --user disable --now xp-sizes.path
remove "$CFG/systemd/user/xp-sizes.path" "$CFG/systemd/user/xp-sizes.service"
run systemctl --user daemon-reload

# 2. The marked blocks. The .pre-xp backup is deleted only when the file is
#    back to exactly what it was; otherwise it is kept and named.
say "Edits to your own files"
strip_block() {
  local file=$1 tmp
  [[ -e $file ]] && grep -qF "$BEGIN" "$file" || { echo "$file: no XP block"; return 0; }
  tmp=$(mktemp)
  # install.sh put exactly one blank line above the block; drop that too.
  awk -v b="$BEGIN" -v e="$END" '
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) if (line[i] == b) { s = i; break }
      for (t = s; t <= NR && line[t] != e; t++);
      if (s > 1 && line[s - 1] == "") s--
      for (i = 1; i <= NR; i++) if (i < s || i > t) print line[i]
    }' "$file" >"$tmp"
  diff -u --label "$file (now)" --label "$file (without XP)" "$file" "$tmp"
  if ((DRY)); then
    rm -f "$tmp"
    return 0
  fi
  cat "$tmp" >"$file" && rm -f "$tmp"
  if [[ -e $file.pre-xp ]]; then
    if cmp -s "$file" "$file.pre-xp"; then rm -f "$file.pre-xp"; else echo "$file differs from $file.pre-xp (edited since install); kept the backup"; fi
  fi
}
strip_block "$CFG/foot/foot.ini"
strip_block "$HOME/.bashrc"
strip_block "$CFG/tmux/tmux.conf"

# 3. The payload (the same list install.sh writes) and the user-level installs.
say "Files"
targets=()
for d in "$PAYLOAD"/omarchy/themes/* "$PAYLOAD"/omarchy/plugins/*; do targets+=("$CFG/omarchy/${d#"$PAYLOAD"/omarchy/}"); done
while IFS= read -r f; do targets+=("$CFG/omarchy/${f#"$PAYLOAD"/omarchy/}"); done < <(find "$PAYLOAD/omarchy/hooks" -type f)
remove "${targets[@]}"
# omarchy/xp last: it holds the marker, and Microsoft's downloaded files (assets/).
remove "$XP"
remove "$DATA/fonts/xp" \
  "$DATA/themes/Windows XP Luna" "$DATA/themes/Windows XP Homestead" "$DATA/themes/Windows XP Metallic" \
  "$DATA/themes/Windows XP Royale" "$DATA/themes/Windows XP Zune" \
  "$DATA/icons/windows-xp" "$DATA/icons/windows-xp-base" "$DATA/icons/windows-xp-cursors" \
  "$HOME/.local/lib/hyprbars-xp" "$HOME/.local/state/omarchy/xp" \
  "$HOME/.local/state/omarchy/toggles/hypr/windows-xp.lua"
run fc-cache -f

say "Left for you (sudo)"
if [[ -d /usr/share/plymouth/themes/windows-xp ]]; then
  echo "The XP boot splash is installed. Put Omarchy's back with:"
  echo "  $PAYLOAD/omarchy/xp/bin/xp-boot off"
fi
echo "The packages only XP uses (keep any you use for something else):"
echo "  sudo pacman -Rns hyprland-plugin-hyprbars xscreensaver"
