#!/bin/bash

SESSION="Sanctuary"
PROJECT_DIR="$HOME/user/Documents/Projects/Sanctuary/"
VAULT_NOTE="$HOME/user/Documents/JB-s-Vault/05 - Fleeting/Sanctuary/sanctuary.md"

# Kill existing session if it exists
tmux kill-session -t $SESSION 2>/dev/null

# Window 1: Claude Code
tmux new-session -d -s $SESSION -n "claude" -c "$PROJECT_DIR"
tmux send-keys -t $SESSION:claude "claude" C-m

# Window 2: Terminal
tmux new-window -t $SESSION -n "terminal" -c "$PROJECT_DIR/Backend/"
tmux split-window -v -p 20 -c "$PROJECT_DIR/UI"

#Window 3: Docker TUI
tmux new-window -t $SESSION -n "Lazydocker"
tmux send-keys -t $SESSION:Lazydocker "lazydocker" C-m


#Window 4: LazySql TUI
tmux new-window -t $SESSION -n "LazySql"
tmux send-keys -t $SESSION:LazySql "lazysql" C-m

# Window 5: Nvim on FinLib notes
tmux new-window -t $SESSION -n "notes"
tmux send-keys -t $SESSION:notes "nvim '$VAULT_NOTE'" C-m

# Focus the Claude Code window
tmux select-window -t $SESSION:claude

# Attach to the session
tmux attach -t $SESSION
