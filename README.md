# AgentBar

A [SwiftBar](https://github.com/swiftbar/SwiftBar) plugin that monitors AI coding agents (Claude Code, Codex) running in tmux and shows their status in the macOS menu bar.

<!-- ![AgentBar screenshot](screenshot.png) -->

## Features

- Live status for each agent session: working, needs approval, idle, exited
- Approve, "Yes always", or decline permission prompts directly from the menu bar
- Shows the agent's last message when idle (no need to switch to terminal)
- Click any session to jump to it in iTerm2
- Desktop notifications on state changes (with optional [terminal-notifier](https://github.com/julienXX/terminal-notifier) for richer alerts)

## Icon Legend

| Icon | Meaning |
|------|---------|
| 🔴   | Needs approval — agent is waiting for permission |
| ⚡   | Working — agent is actively running |
| 🟡   | Idle — agent finished or waiting for input |
| —    | Shell — agent exited, back to shell |

## Prerequisites

- [SwiftBar](https://github.com/swiftbar/SwiftBar) — menu bar plugin framework
- [tmux](https://github.com/tmux/tmux) — terminal multiplexer (agents must run inside tmux)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or another AI coding agent
- macOS with iTerm2 (for session switching)

## Install

```bash
git clone https://github.com/kobvel/agentbar.git
cd agentbar
./install.sh
```

The installer symlinks the plugin files into your SwiftBar plugin directory.

## Configure Claude Code Hooks

Add the following to your `~/.claude/settings.json` (create it if it doesn't exist):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [{ "type": "command", "command": "/path/to/agentbar/agentbar-hook.sh working pretooluse" }]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [{ "type": "command", "command": "/path/to/agentbar/agentbar-hook.sh action permission_prompt" }]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [{ "type": "command", "command": "/path/to/agentbar/agentbar-hook.sh idle idle_prompt" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "/path/to/agentbar/agentbar-hook.sh idle stop" }]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [{ "type": "command", "command": "/path/to/agentbar/agentbar-hook.sh working userpromptsubmit" }]
      }
    ]
  }
}
```

Replace `/path/to/agentbar` with the actual path where you cloned the repo.

## How It Works

1. **`agentbar-hook.sh`** — Claude Code calls this hook on events (tool use, permission prompts, stop). It writes the agent's state to `/tmp/agentbar-state.json`, keyed by tmux pane ID.

2. **`agentbar.30s.sh`** — SwiftBar plugin that reads hook state, cross-references live tmux panes, prunes dead sessions, and renders the menu bar + dropdown. Hooks trigger instant refreshes; the 30s interval is a fallback.

3. **Action scripts** — `approve-session.sh`, `approve-always-session.sh`, `decline-session.sh` send keystrokes to the appropriate tmux pane. `activate-session.sh` switches to the session in iTerm2.

## Optional: terminal-notifier

For richer macOS notifications (with click-to-activate):

```bash
brew install terminal-notifier
```

AgentBar will automatically use it when available, falling back to `osascript` notifications otherwise.

## Files

| File | Purpose |
|------|---------|
| `agentbar.30s.sh` | SwiftBar plugin (30s fallback poll; hooks trigger instant refresh) |
| `agentbar-hook.sh` | Claude Code hook (writes state on events) |
| `activate-session.sh` | Switch to tmux session in iTerm2 |
| `approve-session.sh` | Send Enter to approve |
| `approve-always-session.sh` | Send Down+Enter for "Yes, always" |
| `decline-session.sh` | Send Escape to decline |
| `install.sh` | Symlinks files to SwiftBar plugin dir |
