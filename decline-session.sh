#!/bin/bash
# Decline/cancel action in a tmux session (sends Escape)
SESSION="$1"
WINDOW="$2"

export PATH="/opt/homebrew/bin:$PATH"

tmux send-keys -t "${SESSION}:${WINDOW}" Escape
