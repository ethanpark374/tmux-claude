# tmux-claude

Monitor all your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) instances running across tmux panes — at a glance.

See which instances are **working** or **idle**, how much **context window** is used, the **model**, **session duration**, and **token counts** — without switching panes.

## Features

- **Status Bar** — Always-visible summary (`CC 2 working 3 idle`) refreshed every 5 seconds
- **Interactive Dashboard** — `prefix + m` opens an fzf picker: browse windows, search by name, see full detail in a preview panel, press Enter to jump to that window
- **Enhanced Choose-Tree** — `prefix + w` shows Claude Code status next to each window (`[CC: WORKING | opus-4-6 | ctx 20%]`, `[CC×3: 2W 1I | ctx 45%]` for multi-pane windows)
- **Multi-Pane Detection** — Detects Claude in any pane regardless of how it was launched (wrapper script or versioned binary)
- **Grouped Dashboard** — `claude-monitor` shows instances grouped by tmux window with a tree layout
- **Notifications** — Desktop notifications when an instance finishes, including a snippet of the last response

## Requirements

- Python 3.6+
- tmux 3.2+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [fzf](https://github.com/junegunn/fzf) (installed automatically)

## Install

**One-liner (curl):**

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpark374/tmux-claude/main/install.sh | bash
```

**Or clone:**

```bash
git clone https://github.com/ethanpark374/tmux-claude.git
cd tmux-claude
./install.sh
```

The installer will:
1. Install `fzf` via Homebrew (macOS) or apt (Linux) if not already present
2. Copy `claude-monitor` to `~/.local/bin/`
3. Add tmux keybindings and status bar config to your `~/.tmux.conf`
4. Backup your existing tmux.conf before modifying
5. Reload tmux config automatically

## Usage

### Status Bar (automatic)

After installation, the tmux status bar shows a live summary that refreshes every 5 seconds:

```
[session] 0:window  1:window*     CC 2 working 3 idle | 19:30 19-Mar
```

### Interactive Dashboard — `prefix + m`

Press `prefix + m` to open an fzf-powered window picker:

```
  tmux-claude  7 instances  2 working, 5 idle  20:44  │  Enter: switch  Esc: close
  window>                                          │
  ● WORKING  trading           [CC: WORK | opus..]│  ──────────────────────────
  ● WORKING  test              [CC×2: 2W 0I | 15%]│    [6:0] test  2 panes
  ○ IDLE     search-youtube    [CC: IDLE | opus..]│  ──────────────────────────
  ○ IDLE     git-tmux-claude       [CC: IDLE | son..]  │
  ─          zsh                                   │  ├─  WORKING  6:0.0
                                                   │  │   Dir: ~/workspace/test
                                                   │  │   Model: sonnet-4-6
                                                   │  │   Context: [██░] 15%
                                                   │  └─  IDLE  6:0.1
                                                   │       Dir: ~/workspace/test
```

- **↑↓** — navigate window by window
- **Type** — filter by window name
- **Enter** — switch to selected window
- **Esc** — close

### Enhanced Choose-Tree — `prefix + w`

Press `prefix + w` to open the standard tmux window chooser, annotated with Claude Code status:

```
(0) main: 8 windows
  (1) trading        (2 panes) [CC×2: 1W 1I | ctx 20%]
  (2) search-youtube (1 panes) [CC: IDLE | opus-4-6 | ctx 11% | 26h]
  (3) gcp-vm         (1 panes) [CC: WORKING | opus-4-6 | ctx 4% | 14m]
  (4) zsh            (1 panes)
```

Multi-pane windows show an aggregated summary (`CC×N`). Single-pane windows show model and context detail.

### One-Shot Dashboard

```bash
claude-monitor
```

```
============================================================================
  tmux-claude  7 instances (2 working, 5 idle)  20:44:13
============================================================================

  ▸ [5:1] trading  ──── 2 panes  1 working, 1 idle ──────────────────────
  ├─  WORKING  │  5:1.0
  │    Dir: ~/workspace/trading
  │    PID: 77077  Duration: 1h17m  CPU: 9.2%  Messages: 201
  │    Model: opus-4-6  Context: [███░░░░░░░░░░░░░░░░░] 19%  (200K/1.0M)
  │    Tokens  in: 3  cached: 198.7K  out: 334
  │
  └─  IDLE  │  5:1.1
       Dir: ~/workspace/trading
       PID: 30325  Duration: 19m  CPU: 3.4%  Messages: 0
       (no usage data yet)

  ▸ [6:0] test  ──────────────────────────────────────────────────────────
  └─  IDLE  │  6:0.0
       Dir: ~/workspace/test
       ...
```

### Notifications — `claude-monitor -n`

Run in the background to get desktop notifications when an instance finishes (WORKING → IDLE):

```bash
nohup claude-monitor -n > /dev/null 2>&1 &
```

Notifications include a snippet of the last assistant response:

```
Claude Code - Done
5:1.0 (trading) completed | Context 20% | 1h17m | "Fixed the position sizing logic..."
```

- **macOS**: Native notification with sound
- **Linux**: Uses `notify-send`

### CLI Reference

| Command | Description |
|---------|-------------|
| `claude-monitor` | One-shot grouped dashboard |
| `claude-monitor -w` | Watch mode (3s auto-refresh) |
| `claude-monitor -n` | Watch mode + desktop notifications |
| `claude-monitor --tmux` | Status bar output (used internally) |
| `claude-monitor --update-panes` | Sync window CC status for choose-tree |
| `claude-monitor --pick-window` | Launch fzf interactive dashboard |
| `claude-monitor --window-detail WIN_ID` | Detail for one window (used as fzf preview) |
| `claude-monitor --version` | Show version |

## How It Works

tmux-claude reads data from Claude Code's local files:

- **Session files** (`~/.claude/sessions/{pid}.json`) — Maps PIDs to session IDs, working directories, and start times
- **Conversation files** (`~/.claude/projects/{project}/{sessionId}.jsonl`) — Message history with API usage data
- **Process state** (`ps`) — CPU usage and process state to determine working/idle status

No API calls are made. Everything is read from local files.

### Process Detection

tmux-claude uses a BFS search (depth ≤ 3) through each pane's process tree to find Claude Code:

1. Check if any process has a session file in `~/.claude/sessions/{pid}.json`
2. If not, detect by binary path (`~/.local/share/claude/versions/`)

This handles all launch methods: `claude` wrapper, versioned binaries, or shells with Claude as a child process.

### Status Detection

- **WORKING**: Process state is `R` (running) or CPU usage > 5%
- **IDLE**: Process is sleeping (`S`) and CPU < 5%

### Context Usage

```
context_used = input_tokens + cache_read_input_tokens + cache_creation_input_tokens
context_pct  = context_used / model_max_context
```

## Supported Models

| Model | Context Window |
|-------|---------------|
| claude-opus-4-6 | 1,048,576 (1M) |
| claude-sonnet-4-6 | 200,000 |
| claude-haiku-4-5 | 200,000 |

Unknown models default to 200K context.

## Uninstall

```bash
./uninstall.sh
```

Or manually:

```bash
rm ~/.local/bin/claude-monitor
# Remove the tmux-claude block from ~/.tmux.conf (between >>> tmux-claude begin/end markers)
tmux source-file ~/.tmux.conf
```

## License

MIT
