#!/bin/bash
# Approve and don't ask again - selects option 2 in Claude Code
# "Yes, and don't ask again for: ..."
SESSION="$1"
WINDOW="$2"

export PATH="/opt/homebrew/bin:$PATH"

# Move down to option 2 then press Enter
tmux send-keys -t "${SESSION}:${WINDOW}" Down Enter
