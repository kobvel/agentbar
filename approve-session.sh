#!/bin/bash
# Approve action in a tmux session
# Claude Code: "Yes" is already selected (option 1), just press Enter
SESSION="$1"
WINDOW="$2"

export PATH="/opt/homebrew/bin:$PATH"

tmux send-keys -t "${SESSION}:${WINDOW}" Enter
