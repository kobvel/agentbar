#!/bin/bash
# AgentBar installer — symlinks plugin files into SwiftBar's plugin directory

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect SwiftBar plugin directory
DEFAULT_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
if [ -d "$DEFAULT_DIR" ]; then
    PLUGIN_DIR="$DEFAULT_DIR"
else
    echo "SwiftBar plugin directory not found at:"
    echo "  $DEFAULT_DIR"
    echo ""
    read -rp "Enter your SwiftBar plugin directory: " PLUGIN_DIR
    if [ ! -d "$PLUGIN_DIR" ]; then
        echo "Error: directory does not exist: $PLUGIN_DIR"
        exit 1
    fi
fi

echo "Installing AgentBar to: $PLUGIN_DIR"

# Files to symlink
FILES=(
    agentbar.30s.sh
    agentbar-hook.sh
    activate-session.sh
    approve-session.sh
    approve-always-session.sh
    decline-session.sh
)

for f in "${FILES[@]}"; do
    src="$SCRIPT_DIR/$f"
    dst="$PLUGIN_DIR/$f"

    if [ ! -f "$src" ]; then
        echo "  Warning: $f not found, skipping"
        continue
    fi

    # Remove existing file/symlink
    [ -e "$dst" ] || [ -L "$dst" ] && rm "$dst"

    ln -s "$src" "$dst"
    echo "  Linked $f"
done

# Ensure all are executable
chmod +x "$SCRIPT_DIR"/*.sh

echo ""
echo "Done! AgentBar is installed."
echo ""
echo "Next steps:"
echo "  1. Configure Claude Code hooks — add to ~/.claude/settings.json:"
echo '     {
       "hooks": {
         "PreToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "'"$SCRIPT_DIR"'/agentbar-hook.sh working pretooluse" }] }],
         "PostToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "'"$SCRIPT_DIR"'/agentbar-hook.sh working posttooluse" }] }],
         "Notification": [{ "matcher": "", "hooks": [{ "type": "command", "command": "'"$SCRIPT_DIR"'/agentbar-hook.sh action notification" }] }],
         "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "'"$SCRIPT_DIR"'/agentbar-hook.sh idle stop" }] }]
       }
     }'
echo "  2. Restart SwiftBar (or it will pick up the plugin automatically)"
