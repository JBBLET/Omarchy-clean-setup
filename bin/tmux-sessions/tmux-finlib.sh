#!/bin/bash

SESSION="FinLib"
PROJECT_DIR="$HOME/user/Documents/Projects/FinLib"
VAULT_NOTE="$HOME/user/Documents/JB-s-Vault/05 - Fleeting/FinLib/FinLib Roadmap notes.md"

# Kill existing session if it exists
tmux kill-session -t $SESSION 2>/dev/null

# Window 1: Claude Code
tmux new-session -d -s $SESSION -n "claude" -c "$PROJECT_DIR"
tmux send-keys -t $SESSION:claude "claude" C-m

# Window 2: Terminal in build folder
tmux new-window -t $SESSION -n "build" -c "$PROJECT_DIR/build"

# Window 3: Nvim on FinLib notes
tmux new-window -t $SESSION -n "notes"
tmux send-keys -t $SESSION:notes "nvim '$VAULT_NOTE'" C-m

# Focus the Claude Code window
tmux select-window -t $SESSION:claude

# Attach to the session
tmux attach -t $SESSION
