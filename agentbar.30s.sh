#!/bin/bash

# SwiftBar metadata
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

HOOK_STATE="/tmp/agentbar-state.json"
PREV_STATE="/tmp/agentbar-prev-state"
NOTIFY="/opt/homebrew/bin/terminal-notifier"
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTIVATE_SCRIPT="$PLUGIN_DIR/activate-session.sh"
APPROVE_SCRIPT="$PLUGIN_DIR/approve-session.sh"
APPROVE_ALWAYS_SCRIPT="$PLUGIN_DIR/approve-always-session.sh"
DECLINE_SCRIPT="$PLUGIN_DIR/decline-session.sh"

NOW=$(date +%s)

format_duration() {
    local secs=$1
    if [ "$secs" -lt 60 ]; then
        echo "${secs}s"
    elif [ "$secs" -lt 3600 ]; then
        echo "$(( secs / 60 ))m"
    else
        echo "$(( secs / 3600 ))h$(( (secs % 3600) / 60 ))m"
    fi
}

notify() {
    if [ -x "$NOTIFY" ]; then
        "$NOTIFY" -title "$1" -message "$2" -sound Glass -activate com.googlecode.iterm2 -sender com.googlecode.iterm2 &>/dev/null &
    else
        osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\"" &>/dev/null &
    fi
}

get_prev_state() {
    grep "^${1}|" "$PREV_STATE" 2>/dev/null | head -1 | cut -d'|' -f2
}

touch "$PREV_STATE"

# Use python3 to merge hook state + tmux panes into pipe-delimited lines
# Output: pane_id|status|tool|detail|session|window|path|duration
MERGED=$(python3 -c "
import json, subprocess, sys, os

now = $NOW
hook_state = {}
hook_file = '$HOOK_STATE'
if os.path.exists(hook_file):
    try:
        with open(hook_file) as f:
            hook_state = json.load(f)
    except:
        pass

# Get live tmux panes
try:
    out = subprocess.check_output(
        ['tmux', 'list-panes', '-a', '-F',
         '#{pane_id}|#{session_name}|#{window_index}|#{pane_current_command}|#{pane_current_path}'],
        stderr=subprocess.DEVNULL).decode()
except:
    out = ''

live_panes = {}
for line in out.strip().split('\n'):
    if not line: continue
    parts = line.split('|', 4)
    if len(parts) < 5: continue
    pid, sess, win, cmd, path = parts
    live_panes[pid] = (sess, win, cmd, path)

# Prune dead panes from hook state
changed = False
for pid in list(hook_state.keys()):
    if pid not in live_panes:
        del hook_state[pid]
        changed = True
if changed:
    tmp = hook_file + '.tmp'
    with open(tmp, 'w') as f: json.dump(hook_state, f)
    os.rename(tmp, hook_file)

active_sessions = set()

for pid, (sess, win, cmd, path) in live_panes.items():
    h = hook_state.get(pid)
    if h:
        status = h.get('status', 'working')
        tool = h.get('tool', '')
        detail = h.get('detail', '')
        sess = h.get('session', sess)
        win = h.get('window', win)
        path = h.get('path', path)
        ws = h.get('work_start', 0)
        ts = h.get('timestamp', now)

        # If shell is running but hook says working/action, agent exited
        if cmd in ('zsh', 'bash'):
            status = 'shell'
            detail = 'Agent exited'
            dur = 0
        elif ws and ws > 0:
            dur = now - ws
        else:
            dur = now - ts

        last_msg = h.get('last_message', '')

        # Sanitize pipe chars
        detail = detail.replace('|', ' ')
        tool = tool.replace('|', ' ')
        last_msg = last_msg.replace('|', ' ').replace('\n', ' ')
        print(f'{pid}|{status}|{tool}|{detail}|{sess}|{win}|{path}|{dur}|{last_msg}')
        active_sessions.add(sess)
    else:
        # Only show known agent processes, skip everything else
        if cmd in ('claude', 'codex'):
            print(f'{pid}|idle||Waiting for input|{sess}|{win}|{path}|0|')
            active_sessions.add(sess)

# Output inactive tmux sessions (no active agent panes)
all_sessions = {}
for pid, (sess, win, cmd, path) in live_panes.items():
    if sess not in active_sessions and sess not in all_sessions:
        all_sessions[sess] = (win, pid)
for sess, (win, pid) in sorted(all_sessions.items()):
    print(f'{pid}|inactive|||{sess}|{win}||0|')
" 2>/dev/null)

if [ -z "$MERGED" ]; then
    echo "🤖 —"
    echo "---"
    echo "No agent sessions"
    echo "---"
    echo "Refresh | refresh=true"
    exit 0
fi

# Count statuses
action_count=0
working_count=0
idle_count=0
done_count=0

while IFS='|' read -r _ status _ _ _ _ _ _ _; do
    case "$status" in
        action)  action_count=$((action_count + 1)) ;;
        working) working_count=$((working_count + 1)) ;;
        idle)    idle_count=$((idle_count + 1)) ;;
        shell)   done_count=$((done_count + 1)) ;;
    esac
done <<< "$MERGED"

# Menu bar
active=$(( action_count + working_count + idle_count ))
if [ "$active" -eq 0 ]; then
    echo "🤖 —"
else
    bar=""
    [ "$action_count" -gt 0 ] && bar+="🔴$action_count "
    [ "$working_count" -gt 0 ] && bar+="⚡$working_count "
    [ "$idle_count" -gt 0 ] && bar+="🟡$idle_count "
    echo "${bar% }"
fi

echo "---"

# Dropdown items + notifications
inactive_lines=""

while IFS='|' read -r pane_id status tool detail session_name window_index pane_path duration last_message; do
    [ -z "$pane_id" ] && continue

    dur=$(format_duration "$duration")

    # Notifications on transitions
    prev=$(get_prev_state "$pane_id")
    if [ -n "$prev" ] && [ "$status" != "$prev" ]; then
        if [ "$status" = "action" ]; then
            notify "🔴 $session_name needs action" "${tool:+$tool: }${detail:-Needs approval}"
        elif [ "$status" = "idle" ] && [ "$prev" = "working" ]; then
            notify "🟡 $session_name finished" "Task complete"
        fi
    fi

    # Collect inactive/shell sessions for later
    if [ "$status" = "shell" ] || [ "$status" = "inactive" ]; then
        inactive_lines+="--$session_name | bash='$ACTIVATE_SCRIPT' param1='$session_name' param2='$window_index' param3='$pane_id' terminal=false"$'\n'
        continue
    fi

    case "$status" in
        action)  icon="🔴" ;;
        working) icon="⚡" ;;
        idle)    icon="🟡" ;;
    esac

    if [ "$status" = "action" ]; then
        action_label="${tool:+$tool: }${detail:-Needs approval}"
        echo "$icon $session_name ($dur) — Needs approval | bash='$ACTIVATE_SCRIPT' param1='$session_name' param2='$window_index' param3='$pane_id' terminal=false"
        [ -n "$action_label" ] && echo "--$action_label | color=white size=11"
        echo "--✓ Yes | bash='$APPROVE_SCRIPT' param1='$session_name' param2='$window_index' terminal=false color=green refresh=true"
        [ -f "$APPROVE_ALWAYS_SCRIPT" ] && echo "--✓ Yes, always | bash='$APPROVE_ALWAYS_SCRIPT' param1='$session_name' param2='$window_index' terminal=false color=green refresh=true"
        echo "--✗ No | bash='$DECLINE_SCRIPT' param1='$session_name' param2='$window_index' terminal=false color=red refresh=true"
    else
        status_label="$detail"
        [ "$status" = "working" ] && [ -n "$tool" ] && status_label="$tool"
        echo "$icon $session_name ($dur) — ${status_label:-$status} | bash='$ACTIVATE_SCRIPT' param1='$session_name' param2='$window_index' param3='$pane_id' terminal=false"
        if [ "$status" = "idle" ] && [ -n "$last_message" ]; then
            truncated="${last_message:0:80}"
            [ ${#last_message} -gt 80 ] && truncated="${truncated}…"
            echo "--💬 $truncated | color=white size=11"
        fi
    fi
done <<< "$MERGED"

# Inactive sessions submenu
if [ -n "$inactive_lines" ]; then
    echo "---"
    echo "Inactive | color=gray"
    echo -n "$inactive_lines"
fi

# Save current states for next cycle
echo "$MERGED" | while IFS='|' read -r pane_id status _; do
    echo "${pane_id}|${status}"
done > "$PREV_STATE"

echo "---"
echo "Refresh | refresh=true"
