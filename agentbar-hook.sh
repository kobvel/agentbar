#!/bin/bash
# AgentBar v2 hook — called by Claude Code hooks
# Usage: agentbar-hook.sh <status> <event>
# Env: $TMUX_PANE (set by tmux), stdin = hook JSON context
STATUS="$1"    # working | action | idle
EVENT="$2"     # pretooluse | permission_prompt | idle_prompt | stop | userpromptsubmit

STATE_FILE="/tmp/agentbar-state.json"
PANE="$TMUX_PANE"

# Skip if not in tmux
[ -z "$PANE" ] && { echo "{}"; exit 0; }

# Get tmux session info
TMUX_INFO=$(tmux display-message -t "$PANE" -p "#{session_name}|#{window_index}|#{pane_current_path}" 2>/dev/null)
SESSION=$(echo "$TMUX_INFO" | cut -d'|' -f1)
WINDOW=$(echo "$TMUX_INFO" | cut -d'|' -f2)
PANE_PATH=$(echo "$TMUX_INFO" | cut -d'|' -f3)

# Read hook input from stdin (contains tool_name, tool_input etc.)
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
DETAIL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); inp=d.get('tool_input',{}); print(inp.get('command', inp.get('file_path', ''))[:60])" 2>/dev/null)
LAST_MSG=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('last_assistant_message','')[:200])" 2>/dev/null)

NOW=$(date +%s)

# Escape single quotes for safe embedding in python
DETAIL_ESCAPED=$(echo "$DETAIL" | sed "s/'/\\\\'/g")
LAST_MSG_ESCAPED=$(echo "$LAST_MSG" | sed "s/'/\\\\'/g")

# Atomic JSON update
python3 -c "
import json, os

f = '$STATE_FILE'
try:
    with open(f) as fh:
        state = json.load(fh)
except:
    state = {}

pane = '$PANE'
prev = state.get(pane, {})
prev_work_start = prev.get('work_start')

last_msg = '$LAST_MSG_ESCAPED'

entry = {
    'status': '$STATUS',
    'event': '$EVENT',
    'tool': '$TOOL',
    'detail': '$DETAIL_ESCAPED',
    'session': '$SESSION',
    'window': '$WINDOW',
    'path': '$PANE_PATH',
    'timestamp': $NOW
}

# Store last_message on stop events, preserve from previous state otherwise
if last_msg:
    entry['last_message'] = last_msg
elif prev.get('last_message'):
    entry['last_message'] = prev['last_message']

# Preserve work_start while working, set on first transition, clear otherwise
if '$STATUS' == 'working':
    entry['work_start'] = prev_work_start if prev_work_start else $NOW
# action keeps work_start too (still mid-task)
elif '$STATUS' == 'action':
    if prev_work_start:
        entry['work_start'] = prev_work_start

state[pane] = entry

tmp = f + '.tmp'
with open(tmp, 'w') as fh:
    json.dump(state, fh)
os.rename(tmp, f)
"

# Trigger SwiftBar refresh so menu bar updates instantly
open -g "swiftbar://refreshplugin?name=agentbar" &>/dev/null &

# Must output valid JSON for Claude Code to accept
echo "{}"
