#!/bin/bash
# Switch to specific tmux session:window and activate iTerm2
SESSION="$1"
WINDOW="$2"

export PATH="/opt/homebrew/bin:$PATH"

# Select the right tmux session and window
tmux select-window -t "${SESSION}:${WINDOW}" 2>/dev/null
tmux switch-client -t "${SESSION}" 2>/dev/null

# Bring iTerm2 to front
osascript -e 'tell application "iTerm2" to activate'
