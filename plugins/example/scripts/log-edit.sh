#!/bin/bash
# Log file edits made by Claude Code
# Receives hook input as JSON on stdin

FILE_PATH=$(jq -r '.tool_input.file_path // empty')

if [ -n "$FILE_PATH" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Edited: $FILE_PATH" >> "${CLAUDE_PLUGIN_ROOT}/edit.log"
fi
