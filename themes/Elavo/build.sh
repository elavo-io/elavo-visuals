#!/usr/bin/env bash
# Builds the light and dark CSS from src/:
# gtk-4.0/gtk.css, gtk-4.0/gtk-dark.css, gtk-4.0/libadwaita.css,
# gtk-3.0/gtk.css, and gtk-3.0/gtk-dark.css.
# The compiled CSS is committed, so installing the theme needs no Sass.
#
# Needs sassc, or pysassc from `pip install libsass`. Both are libsass,
# the compiler GTK builds its own theme with.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src="$here/src/gtk-4.0"
out="$here/gtk-4.0"

if command -v sassc >/dev/null; then
  sass=(sassc)
elif command -v pysassc >/dev/null; then
  sass=(pysassc)
else
  echo "build.sh: install sassc, or run: pip install libsass" >&2
  exit 1
fi

compile() {
  "${sass[@]}" -I "$src" "$1" "$2"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

compile "$src/gtk.scss" "$out/gtk.css"
compile "$src/gtk-dark.scss" "$out/gtk-dark.css"
compile "$src/libadwaita.scss" "$tmp/built-libadwaita-light.css"
compile "$src/libadwaita-dark.scss" "$tmp/built-libadwaita-dark.css"
cat "$tmp/built-libadwaita-light.css" "$tmp/built-libadwaita-dark.css" > "$out/libadwaita.css"
"${sass[@]}" -I "$src" "$here/src/gtk-3.0/gtk.scss" "$here/gtk-3.0/gtk.css"
"${sass[@]}" -I "$src" "$here/src/gtk-3.0/gtk-dark.scss" "$here/gtk-3.0/gtk-dark.css"

# The accent must stay a runtime value. Build again with a different
# default accent. Only the lines that declare the default may change;
# any other difference is an accent shade Sass computed at build time.
leak_check() {
  local built="$1"
  local candidate="$2"
  local label="$3"
  local leaked
  leaked=$(diff "$built" "$candidate" | grep '^[<>]' \
    | grep -v -E -e '--accent-(bg|fg)-color: (#|var\(--elavo-accent-)' \
                 -e '@define-color (theme_selected_(bg|fg)_color|theme_unfocused_selected_(bg|fg)_color|accent_color) ' || true)
  if [ -n "$leaked" ]; then
    echo "build.sh: accent color computed at build time in $label:" >&2
    echo "$leaked" >&2
    exit 1
  fi
}

for sheet in gtk gtk-dark libadwaita libadwaita-dark; do
  printf '$elavo-accent-default: graphite;\n@import "%s";\n' "$sheet" > "$tmp/check-$sheet.scss"
  compile "$tmp/check-$sheet.scss" "$tmp/graphite-$sheet.css"
done
leak_check "$out/gtk.css" "$tmp/graphite-gtk.css" "gtk.css"
leak_check "$out/gtk-dark.css" "$tmp/graphite-gtk-dark.css" "gtk-dark.css"
cat "$tmp/graphite-libadwaita.css" "$tmp/graphite-libadwaita-dark.css" > "$tmp/graphite-libadwaita-joined.css"
leak_check "$out/libadwaita.css" "$tmp/graphite-libadwaita-joined.css" "libadwaita.css"

for sheet in gtk gtk-dark; do
  printf '$elavo-accent-default: graphite;\n@import "%s";\n' "$sheet" > "$tmp/check-gtk3-$sheet.scss"
  "${sass[@]}" -I "$here/src/gtk-3.0" -I "$src" "$tmp/check-gtk3-$sheet.scss" "$tmp/graphite-gtk3-$sheet.css"
  leak_check "$here/gtk-3.0/$sheet.css" "$tmp/graphite-gtk3-$sheet.css" "gtk-3.0/$sheet.css"
done

radius=$(sed -n 's/^\$elavo-window-radius:[[:space:]]*\([0-9][0-9]*\)px;.*/\1/p' "$src/_elavo-tokens.scss")
if [ -z "$radius" ]; then
  echo "build.sh: \$elavo-window-radius is missing from _elavo-tokens.scss" >&2
  exit 1
fi
themerc="$here/openbox-3/themerc"
marker="# elavo-window-tokens"
filtered=$(mktemp)
awk -v marker="$marker" '
  $0 == marker { skip = 1; next }
  skip && $0 ~ /^window\.(cornerRadius|maximizedCorners|dropShadows|dropShadowsOnTiled|dropShadowsOnMaximized|blur)/ { next }
  skip && $0 == "" { skip = 0; next }
  { print }
' "$themerc" > "$filtered"
mv "$filtered" "$themerc"
cat >> "$themerc" <<EOF
$marker
window.cornerRadius: $radius
window.maximizedCorners: yes
window.dropShadows: yes
window.dropShadowsOnTiled: yes
window.dropShadowsOnMaximized: yes
window.blur.strength: 3
EOF

python3 - "$src/_elavo-tokens.scss" "$src/_elavo-tokens-dark.scss" "$themerc" "$here/openbox-3/themerc-dark" <<'PY'
import re
import sys

light_path, dark_path, themerc_path, dark_out = sys.argv[1:5]


def parse(path):
    colors = {}
    for line in open(path):
        match = re.match(r"\$([A-Za-z0-9-]+):\s*([^;]+);", line)
        if match:
            colors[match.group(1)] = match.group(2).strip()
    return colors


def hex_of(value):
    value = value.strip()
    if value.startswith("#"):
        return value.lower()
    match = re.fullmatch(
        r"rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)", value
    )
    if not match:
        raise SystemExit(f"unrecognized color {value}")
    red, green, blue = (int(match.group(i)) for i in range(1, 4))
    alpha = int(round(float(match.group(4)) * 255))
    if alpha >= 255:
        return f"#{red:02x}{green:02x}{blue:02x}"
    return f"#{red:02x}{green:02x}{blue:02x}{alpha:02x}"


def block(colors):
    header = hex_of(colors["elavo-headerbar-bg"])
    foreground = hex_of(colors["elavo-fg"])
    # The GTK theme has no unfocused title color. 55% of the foreground reads
    # as the dim title an unfocused window uses.
    dim = foreground + "8c"
    border = hex_of(colors["elavo-border"])
    hover = hex_of(colors["elavo-row-hover"])
    chosen = hex_of(colors["elavo-backdrop-selection"])
    popover = hex_of(colors["elavo-popover-bg"])
    hairline = hex_of(colors["elavo-hairline"])
    lines = [
        f"window.active.title.bg.color: {header}",
        f"window.inactive.title.bg.color: {header}",
        f"window.active.label.text.color: {foreground}",
        f"window.inactive.label.text.color: {dim}",
        f"window.active.border.color: {border}",
        f"window.inactive.border.color: {border}",
        f"window.button.hover.bg.color: {hover}",
        f"menu.items.bg.color: {popover}",
        f"menu.items.text.color: {foreground}",
        f"menu.items.active.bg.color: {chosen}",
        f"menu.items.active.text.color: {foreground}",
        f"menu.separator.color: {hairline}",
        f"menu.title.bg.color: {header}",
        f"menu.title.text.color: {foreground}",
        f"menu.border.color: {border}",
        f"osd.bg.color: {popover}",
        f"osd.border.color: {border}",
        f"osd.label.text.color: {foreground}",
    ]
    return "\n".join(lines) + "\n"


light = parse(light_path)
dark = dict(light)
dark.update(parse(dark_path))

start = "# elavo-window-colors"
end = "# elavo-window-colors-end"
text = open(themerc_path).read()
chunk = start + "\n" + block(light) + end + "\n"
if start not in text or end not in text:
    raise SystemExit("themerc is missing the elavo-window-colors markers")
text = re.sub(
    re.escape(start) + r".*?" + re.escape(end) + r"\n",
    chunk,
    text,
    count=1,
    flags=re.S,
)
open(themerc_path, "w").write(text)
open(dark_out, "w").write(
    "# Dark labwc colors, written by build.sh from _elavo-tokens-dark.scss.\n"
    "# elavo-labwc-theme points ~/.config/labwc/themerc-override here while\n"
    "# the color scheme is prefer-dark. labwc reads it after themerc.\n"
    + block(dark)
)
PY

echo "Built gtk-4.0/gtk.css, gtk-4.0/gtk-dark.css, gtk-4.0/libadwaita.css, gtk-3.0/gtk.css, gtk-3.0/gtk-dark.css"
