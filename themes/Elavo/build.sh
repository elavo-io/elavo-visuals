#!/usr/bin/env bash
# Builds gtk-4.0/gtk.css, gtk-4.0/libadwaita.css, and gtk-3.0/gtk.css
# from src/.
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

compile "$src/gtk.scss" "$out/gtk.css"
compile "$src/libadwaita.scss" "$out/libadwaita.css"
"${sass[@]}" -I "$src" "$here/src/gtk-3.0/gtk.scss" "$here/gtk-3.0/gtk.css"

# The accent must stay a runtime value. Build again with a different
# default accent. Only the lines that declare the default may change;
# any other difference is an accent shade Sass computed at build time.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for sheet in gtk libadwaita; do
  printf '$elavo-accent-default: graphite;\n@import "%s";\n' "$sheet" > "$tmp/check-$sheet.scss"
  compile "$tmp/check-$sheet.scss" "$tmp/$sheet.css"
  leaked=$(diff "$out/$sheet.css" "$tmp/$sheet.css" | grep '^[<>]' \
    | grep -v -E -e '--accent-(bg|fg)-color: (#|var\(--elavo-accent-)' \
                 -e '@define-color (theme_selected_(bg|fg)_color|theme_unfocused_selected_(bg|fg)_color|accent_color) ' || true)
  if [ -n "$leaked" ]; then
    echo "build.sh: accent color computed at build time in $sheet.css:" >&2
    echo "$leaked" >&2
    exit 1
  fi
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

echo "Built gtk-4.0/gtk.css, gtk-4.0/libadwaita.css, gtk-3.0/gtk.css"
