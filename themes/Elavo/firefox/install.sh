#!/bin/sh
# Put the Elavo window buttons into every Firefox profile of this user: the
# RPM's (~/.mozilla/firefox) and the Flatpak's (~/.var/app/org.mozilla.firefox).
# Safe to run again. A profile's own userChrome.css is kept; one @import line
# is added at its top. Firefox applies the change when it next starts.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
art="${here}/../openbox-3"
pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
import='@import url("elavo/elavo-window-buttons.css");'

install_profile() {
    profile="$1"
    chrome="${profile}/chrome"
    mkdir -p "${chrome}/elavo"
    cp -f "${here}/elavo-window-buttons.css" "${chrome}/elavo/"
    for name in close-default close-defocused close-hover minimize-default \
                minimize-hover maximize-default maximize-hover; do
        cp -fL "${art}/${name}-500px.png" "${chrome}/elavo/"
    done

    # @import must come before any other rule in the file.
    css="${chrome}/userChrome.css"
    if ! grep -qsF "${import}" "${css}"; then
        { echo "${import}"; cat "${css}" 2>/dev/null || true; } > "${css}.new"
        mv -f "${css}.new" "${css}"
    fi

    grep -qsF "${pref}" "${profile}/user.js" || echo "${pref}" >> "${profile}/user.js"
    echo "Elavo window buttons: ${profile}"
}

for root in "${HOME}/.mozilla/firefox" \
            "${HOME}/.var/app/org.mozilla.firefox/.mozilla/firefox" \
            "${HOME}/.var/app/org.mozilla.firefox/config/mozilla/firefox"; do
    [ -f "${root}/profiles.ini" ] || continue
    sed -n 's/^Path=//p' "${root}/profiles.ini" | while read -r path; do
        case "${path}" in
            /*) profile="${path}" ;;
            *) profile="${root}/${path}" ;;
        esac
        if [ -d "${profile}" ]; then
            install_profile "${profile}"
        fi
    done
done
