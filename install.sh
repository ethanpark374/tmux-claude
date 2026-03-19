#!/usr/bin/env bash
set -euo pipefail

# tmux-claude installer
# Usage:
#   git clone https://github.com/ethanpark374/tmux-claude && cd tmux-claude && ./install.sh
#   curl -fsSL https://raw.githubusercontent.com/ethanpark374/tmux-claude/main/install.sh | bash

REPO_URL="https://raw.githubusercontent.com/ethanpark374/tmux-claude/main"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="claude-monitor"
MARKER_BEGIN="# >>> tmux-claude begin >>>"
MARKER_END="# <<< tmux-claude end <<<"

# Detect tmux.conf location
if [ -f "${HOME}/.config/tmux/tmux.conf" ]; then
    TMUX_CONF="${HOME}/.config/tmux/tmux.conf"
elif [ -f "${HOME}/.tmux.conf" ]; then
    TMUX_CONF="${HOME}/.tmux.conf"
else
    TMUX_CONF="${HOME}/.tmux.conf"
fi

info()  { printf "\033[34m[tmux-claude]\033[0m %s\n" "$1"; }
ok()    { printf "\033[32m[tmux-claude]\033[0m %s\n" "$1"; }
warn()  { printf "\033[33m[tmux-claude]\033[0m %s\n" "$1"; }
error() { printf "\033[31m[tmux-claude]\033[0m %s\n" "$1"; exit 1; }

# --- Pre-flight checks ---
command -v python3 >/dev/null 2>&1 || error "python3 is required but not found."
command -v tmux >/dev/null 2>&1    || error "tmux is required but not found."

# --- Install fzf (required for prefix+w window picker) ---
if ! command -v fzf >/dev/null 2>&1; then
    info "fzf not found. Installing fzf (required for window picker)..."
    if command -v brew >/dev/null 2>&1; then
        brew install fzf && ok "fzf installed via Homebrew."
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y fzf && ok "fzf installed via apt."
    else
        warn "Could not install fzf automatically. Install it manually: https://github.com/junegunn/fzf"
        warn "prefix+w window picker will show a static list until fzf is installed."
    fi
else
    ok "fzf already installed ($(fzf --version))."
fi

info "Installing tmux-claude..."

# --- Install script ---
mkdir -p "${INSTALL_DIR}"

# If running from cloned repo, copy from local; otherwise download
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "${SCRIPT_DIR}/claude-monitor" ]; then
    cp "${SCRIPT_DIR}/claude-monitor" "${INSTALL_DIR}/${SCRIPT_NAME}"
    info "Copied from local repo."
else
    curl -fsSL "${REPO_URL}/claude-monitor" -o "${INSTALL_DIR}/${SCRIPT_NAME}"
    info "Downloaded from GitHub."
fi
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
ok "Installed ${SCRIPT_NAME} -> ${INSTALL_DIR}/${SCRIPT_NAME}"

# --- Check PATH ---
if ! echo "${PATH}" | tr ':' '\n' | grep -qx "${INSTALL_DIR}"; then
    warn "${INSTALL_DIR} is not in your PATH."
    warn "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
    warn "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

# --- Patch tmux.conf ---
TMUX_BLOCK=$(cat <<'TMUXEOF'
# tmux-claude: Claude Code Monitor (https://github.com/ethanpark374/tmux-claude)
set -g status-interval 5
set -g status-right-length 80
set -g status-right '#(python3 ~/.local/bin/claude-monitor --tmux) | %H:%M %d-%b'

# prefix + m: interactive dashboard + fzf window picker
bind m display-popup -E -w 85 -h 90% "python3 ~/.local/bin/claude-monitor --pick-window"

# prefix + w: choose-tree with CC status
bind w run-shell "python3 ~/.local/bin/claude-monitor --update-panes" \; choose-tree -Zw -F "#{window_index}:#{window_name}#{window_flags} (#{window_panes} panes) #{@cc_window_info}"
TMUXEOF
)

# Create tmux.conf if it doesn't exist
touch "${TMUX_CONF}"

# Remove old block if present (idempotent)
if grep -qF "${MARKER_BEGIN}" "${TMUX_CONF}"; then
    info "Removing previous tmux-claude config..."
    sed -i.tmp "/${MARKER_BEGIN}/,/${MARKER_END}/d" "${TMUX_CONF}"
    rm -f "${TMUX_CONF}.tmp"
fi

# Backup
if [ ! -f "${TMUX_CONF}.bak.tmux-claude" ]; then
    cp "${TMUX_CONF}" "${TMUX_CONF}.bak.tmux-claude"
    info "Backed up ${TMUX_CONF} -> ${TMUX_CONF}.bak.tmux-claude"
fi

# Append config block
{
    echo ""
    echo "${MARKER_BEGIN}"
    echo "${TMUX_BLOCK}"
    echo "${MARKER_END}"
} >> "${TMUX_CONF}"
ok "Added tmux-claude config to ${TMUX_CONF}"

# --- Reload tmux if running ---
if tmux info >/dev/null 2>&1; then
    tmux source-file "${TMUX_CONF}" 2>/dev/null && ok "Reloaded tmux config." || warn "Could not reload tmux config. Run: tmux source-file ${TMUX_CONF}"
fi

echo ""
ok "Installation complete!"
echo ""
info "Usage:"
info "  claude-monitor        One-shot dashboard"
info "  claude-monitor -w     Watch mode (auto-refresh)"
info "  claude-monitor -n     Watch + macOS/Linux notifications"
info "  prefix + m            Popup dashboard (q to close)"
info "  prefix + w            Choose-tree with Claude Code status"
echo ""
