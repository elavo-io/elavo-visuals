# Elavo theme

The GTK theme and labwc title-bar theme for Elavo. Light only for now.

| Path | What it is |
| --- | --- |
| `gtk-4.0/gtk.css` | The GTK4 theme. Compiled; do not edit. |
| `gtk-4.0/libadwaita.css` | Elavo for libadwaita apps such as Files. Compiled; do not edit. |
| `gtk-4.0/assets/` | Check, radio, and slider art from GTK, and the window-button PNGs. |
| `gtk-3.0/gtk.css` | GTK3 stopgap: GTK3's built-in Adwaita, Elavo's named colors, and the window buttons. Compiled. |
| `openbox-3/` | labwc server-side decorations. |
| `firefox/` | Window buttons for Firefox's own title bar, which ignores GTK's. `firefox/install.sh` adds them to every Firefox profile, RPM and Flatpak. |
| `src/` | The SCSS everything above is built from. |
| `build.sh` | Rebuilds the compiled CSS. |

## Install

Copy this directory to `~/.local/share/themes/Elavo` or `/usr/share/themes/Elavo`, and set `gtk-theme-name=Elavo` in `gtk-4.0/settings.ini` and `gtk-3.0/settings.ini`. Nothing else is needed for plain GTK apps; the CSS is self-contained.

libadwaita apps do not load `gtk-theme-name`. To style them, `~/.config/gtk-4.0/gtk.css` imports the libadwaita sheet and the accent file:

```css
@import url("file:///usr/share/themes/Elavo/gtk-4.0/libadwaita.css");
@import url("elavo-accent.css");
```

That user stylesheet sits above every GTK4 app's own CSS, including `elavo-shell`, so `libadwaita.css` scopes its widget rules to `toolbarview`, which only libadwaita windows have. Under a dark color-scheme preference, libadwaita apps keep libadwaita's dark palette until Elavo has a dark variant.

For labwc, select `Elavo` in `rc.xml` (`<theme><name>Elavo</name></theme>`).

## Accent color

The accent is one runtime value, `--accent-bg-color`, with `--accent-fg-color` for text drawn on it. Every place the accent appears reads it: the selected sidebar row, list selection, the highlighted menu item, the default button, checked checks, radios, and switches, sliders, progress, links, focus rings, and text selection. Shades such as pressed and focus are worked out by GTK when it draws (`color-mix()`, `hsl(from …)`), not by Sass, so changing the value changes all of them.

`~/.config/gtk-4.0/elavo-accent.css` overrides it:

```css
:root { --accent-bg-color: #d93b36; --accent-fg-color: #ffffff; }
```

An empty file means the theme default. The presets and their GNOME accent names are in `src/gtk-4.0/_elavo-accents.scss`. A settings pane should write this file and also set `org.gnome.desktop.interface accent-color` to the matching GNOME name, which is how libadwaita Flatpaks get the accent. GTK reads the user stylesheet when an app starts.

The legacy named colors (`@theme_selected_bg_color`, `@accent_color`) cannot hold a `var()`. They are the compiled default and do not follow the user's accent. Use `var(--accent-bg-color)` instead. GTK3 has no `var()`; its accent is the compiled default unless `~/.config/gtk-3.0/gtk.css` overrides `@theme_selected_bg_color`.

`build.sh` builds a second time with a different default accent and fails if anything other than the default's own declarations changed. That catches an accent shade computed by Sass at build time.

## Build

```bash
pip install libsass   # or install sassc
./build.sh
```

Both are libsass, the compiler GTK builds its own theme with.

## Source layout

`src/gtk-4.0/` starts from GTK's built-in theme, `gtk/theme/Default` at GTK tag `4.22.5` (commit `bd25f1e2dc2c2fbf3b8864e61afe642910ba359c`). That code, and this theme as derived from it, are under the GNU LGPL, version 2 or later; see `COPYING`. The window-button PNGs are Elavo artwork from `ui/window-decorations`.

| File | Origin |
| --- | --- |
| `_common.scss` | GTK, with the radius variables at the top pointed at the Elavo tokens. |
| `_drawing.scss` | GTK, unchanged. |
| `_colors-public.scss` | GTK, with the accent-based named colors set to the compiled default. |
| `_colors.scss` | Elavo. Replaces GTK's palette with the tokens, using GTK's variable names. |
| `_elavo-tokens.scss` | Elavo colors, sizes, radii, shadows, and font. |
| `_elavo-accents.scss` | Accent presets. |
| `_elavo-functions.scss` | Replaces Sass's `darken`, `lighten`, `mix`, `transparentize`, `opacify`, `desaturate`, and `invert` so they also accept the accent variable. |
| `_elavo-drawing.scss` | Redefines GTK's `button`, `entry`, `check`, `focus-ring`, and `headerbar_fill` mixins. |
| `_elavo-shapes.scss` | Elavo metrics and accent placement, used by both sheets. |
| `_elavo-faces.scss` | Button, entry, and check faces for libadwaita, which draws its own. |
| `_elavo-window-buttons.scss` | The window buttons. |

To take a newer GTK release, diff its `gtk/theme/Default` against the tag above and carry the changes into `_common.scss` and `_drawing.scss`. The Elavo files sit beside them, so that diff stays small.

## Window buttons

16px, 8px apart, in the order close, minimize, maximize. Title bars are 46px, and the first button sits 15px from the top and 19px from the left, on client-side bars and labwc's alike. In title bars an app draws itself, hovering any button lights all three, and the hover art fades in over 150ms. An unfocused window shows `close-defocused-500px.png` on every button until the group is hovered. A disabled button stays on the defocused art. labwc lights only the button under the pointer, and GTK3 does the same.

When the art in `ui/window-decorations` changes, copy it into `openbox-3/`. The `gtk-4.0/assets` and `gtk-3.0/assets` entries are symlinks to those copies.
