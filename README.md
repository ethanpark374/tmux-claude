# tmux-cc

Monitor all your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) instances running across tmux panes — at a glance.

See which instances are **working** or **idle**, how much **context window** is used, the **model**, **session duration**, and **token counts** — without switching panes.

<!-- ![tmux-cc dashboard](screenshots/dashboard.png) -->

## Features

- **Status Bar** — Always-visible summary in tmux status bar (`CC 2 working 3 idle`)
- **Popup Dashboard** — Full dashboard overlay with `prefix + m`, scrollable, press `q` to close
- **Enhanced Choose-Tree** — `prefix + w` shows Claude Code status next to each window/pane
- **Notifications** — macOS/Linux desktop notifications when a Claude Code instance finishes work
- **Watch Mode** — Auto-refreshing terminal dashboard

## Requirements

- Python 3.6+
- tmux 3.2+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Install

**One-liner (curl):**

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpark374/tmux-cc/main/install.sh | bash
```

**Or clone:**

```bash
git clone https://github.com/ethanpark374/tmux-cc.git
cd tmux-cc
./install.sh
```

The installer will:
1. Copy `claude-monitor` to `~/.local/bin/`
2. Add tmux keybindings and status bar config to your `~/.tmux.conf`
3. Backup your existing tmux.conf before modifying
4. Reload tmux config automatically

## Usage

### Status Bar (automatic)

After installation, the tmux status bar shows a live summary that refreshes every 5 seconds:

```
[session] 0:window  1:window*     CC 2 working 3 idle | 19:30 19-Mar
```

### Popup Dashboard — `prefix + m`

Press `prefix + m` (default: `Ctrl+b` then `m`) to open a full dashboard overlay:

```
============================================================================
  tmux-cc  6 instances (1 working, 5 idle)  19:33:40
============================================================================

  WORKING   5:1.0 (trading)
  | Dir: ~/workspace/trading
  | PID: 77077  Duration: 10m  CPU: 11.9%  Messages: 37
  | Model: opus-4-6  Context: [██░░░░░░░░░░░░░░░░░░] 4%  (43.8K/1.0M)
  | Tokens  in: 3  cached: 43.2K  out: 8

   IDLE    1:1.0 (search-youtube)
  | Dir: ~/workspace/search-youtube
  | PID: 66111  Duration: 24h59m  CPU: 0.0%  Messages: 204
  | Model: opus-4-6  Context: [██░░░░░░░░░░░░░░░░░░] 11%  (110.7K/1.0M)
  | Tokens  in: 3  cached: 110.6K  out: 261
```

Scroll with arrow keys, `j`/`k`, Page Up/Down. Press `q` to close.

### Enhanced Choose-Tree — `prefix + w`

Press `prefix + w` to see the standard tmux window picker with Claude Code info:

```
(0) 1: 6 windows
  (1) 0: trading-data (1 panes) [CC: IDLE | 19h55m]
  (2) 1: search-youtube (1 panes) [CC: IDLE | opus-4-6 | ctx 10% | 24h59m]
  (3) 2: gcp-vm (1 panes) [CC: WORKING | opus-4-6 | ctx 4% | 14m]
  (4) 3: node (1 panes)
```

Non-Claude panes show normally without the `[CC: ...]` tag.

### Notifications — `claude-monitor -n`

Run in a spare pane or background to get desktop notifications when any Claude Code instance finishes work (WORKING → IDLE transition):

```bash
# In a tmux pane
claude-monitor -n

# Or in the background
nohup claude-monitor -n > /dev/null 2>&1 &
```

- **macOS**: Native notification with sound
- **Linux**: Uses `notify-send`

### CLI Commands

| Command | Description |
|---------|-------------|
| `claude-monitor` | One-shot dashboard |
| `claude-monitor -w` | Watch mode (3s auto-refresh) |
| `claude-monitor -n` | Watch mode + desktop notifications |
| `claude-monitor --tmux` | Status bar output (used internally) |
| `claude-monitor --update-panes` | Update pane variables (used internally) |
| `claude-monitor --version` | Show version |

## How It Works

tmux-cc reads data from Claude Code's local files:

- **Session files** (`~/.claude/sessions/{pid}.json`) — Maps process PIDs to session IDs, working directories, and start times
- **Conversation files** (`~/.claude/projects/{project}/{sessionId}.jsonl`) — Contains message history with API usage data (input tokens, cached tokens, output tokens, model info)
- **Process state** (`ps`) — CPU usage and process state (R=running, S=sleeping) to determine working/idle status

No API calls are made. Everything is read from local files.

### Status Detection

- **WORKING**: Process state is `R` (running) or CPU usage > 5%
- **IDLE**: Process is sleeping (`S` state) and CPU < 5% (waiting for user input)

### Context Usage

Context percentage is calculated from the last API response's usage data:

```
context_used = input_tokens + cache_read_input_tokens + cache_creation_input_tokens
context_max  = model's max context window (e.g., 1M for opus-4-6, 200K for sonnet)
```

## Uninstall

```bash
# From the cloned repo
./uninstall.sh

# Or manually
rm ~/.local/bin/claude-monitor
# Remove the tmux-cc block from your tmux.conf (between >>> tmux-cc begin/end markers)
tmux source-file ~/.tmux.conf
```

## Supported Models

| Model | Context Window |
|-------|---------------|
| claude-opus-4-6 | 1,048,576 (1M) |
| claude-sonnet-4-6 | 200,000 |
| claude-haiku-4-5 | 200,000 |

New models are automatically supported with a default 200K context window.

## License

MIT
