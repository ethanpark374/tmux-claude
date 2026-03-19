#!/usr/bin/env bash
set -euo pipefail

# tmux-cc uninstaller

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="claude-monitor"
MARKER_BEGIN="# >>> tmux-cc begin >>>"
MARKER_END="# <<< tmux-cc end <<<"

# Detect tmux.conf location
if [ -f "${HOME}/.config/tmux/tmux.conf" ]; then
    TMUX_CONF="${HOME}/.config/tmux/tmux.conf"
else
    TMUX_CONF="${HOME}/.tmux.conf"
fi

info()  { printf "\033[34m[tmux-cc]\033[0m %s\n" "$1"; }
ok()    { printf "\033[32m[tmux-cc]\033[0m %s\n" "$1"; }
warn()  { printf "\033[33m[tmux-cc]\033[0m %s\n" "$1"; }

# --- Remove script ---
if [ -f "${INSTALL_DIR}/${SCRIPT_NAME}" ]; then
    rm "${INSTALL_DIR}/${SCRIPT_NAME}"
    ok "Removed ${INSTALL_DIR}/${SCRIPT_NAME}"
else
    warn "${SCRIPT_NAME} not found in ${INSTALL_DIR}"
fi

# --- Remove tmux.conf block ---
if [ -f "${TMUX_CONF}" ] && grep -qF "${MARKER_BEGIN}" "${TMUX_CONF}"; then
    sed -i.tmp "/${MARKER_BEGIN}/,/${MARKER_END}/d" "${TMUX_CONF}"
    rm -f "${TMUX_CONF}.tmp"
    ok "Removed tmux-cc config from ${TMUX_CONF}"

    # Reload tmux if running
    if tmux info >/dev/null 2>&1; then
        tmux source-file "${TMUX_CONF}" 2>/dev/null || true
        ok "Reloaded tmux config."
    fi
else
    warn "No tmux-cc config found in ${TMUX_CONF}"
fi

# --- Clean up pane variables ---
if tmux info >/dev/null 2>&1; then
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null | while read -r pane_id; do
        tmux set-option -p -t "${pane_id}" -u @cc_info 2>/dev/null || true
    done
    ok "Cleared pane variables."
fi

echo ""
ok "Uninstall complete!"
info "Backup of your tmux.conf is at: ${TMUX_CONF}.bak.tmux-cc"
