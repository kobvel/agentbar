#!/bin/bash
# Focus the given tmux session/pane and switch to the correct iTerm2 tab
# If the tmux session has no attached client, open it in a new iTerm2 tab
SESSION="$1"
WINDOW="$2"
PANE_ID="$3"

export PATH="/opt/homebrew/bin:$PATH"

# Select the right tmux window and pane
tmux select-window -t "${SESSION}:${WINDOW}" 2>/dev/null
[ -n "$PANE_ID" ] && tmux select-pane -t "$PANE_ID" 2>/dev/null

# Flash the pane briefly
if [ -n "$PANE_ID" ]; then
    tmux select-pane -t "$PANE_ID" -P 'bg=colour235' 2>/dev/null
    (sleep 0.3 && tmux select-pane -t "$PANE_ID" -P 'default' 2>/dev/null) &
fi

# Get the tty of the most recent client attached to this session
CLIENT_TTY=$(tmux list-clients -t "$SESSION" -F '#{client_activity} #{client_tty}' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')

if [ -n "$CLIENT_TTY" ]; then
    # Find the iTerm2 tab with this tty and focus it
    osascript -e '
    tell application "iTerm2"
        activate
        set targetTTY to "'"$CLIENT_TTY"'"
        repeat with w in windows
            repeat with t in tabs of w
                repeat with s in sessions of t
                    if tty of s is targetTTY then
                        select t
                        tell w to select
                        return
                    end if
                end repeat
            end repeat
        end repeat
    end tell
    ' 2>/dev/null
else
    # Session is detached — open a new iTerm2 tab and attach
    osascript -e '
    tell application "iTerm2"
        activate
        if (count of windows) = 0 then
            create window with default profile
        else
            tell current window
                create tab with default profile
            end tell
        end if
        tell current session of current window
            write text "tmux attach-session -t '"$SESSION"'"
        end tell
    end tell
    ' 2>/dev/null
fi
