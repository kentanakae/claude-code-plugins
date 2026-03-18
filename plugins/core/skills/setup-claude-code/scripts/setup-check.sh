#!/bin/bash
# Claude Code setup health check - runs on SessionStart
# Reminds user to run /setup-claude-code if last check was >7 days ago

TIMESTAMP_FILE="$HOME/.claude/.last-setup-check"
INTERVAL_DAYS=7

# If timestamp file doesn't exist, /setup-claude-code has never been run
if [ ! -f "$TIMESTAMP_FILE" ]; then
    echo "/setup-claude-code がまだ実行されていません。初回の設定チェックを /setup-claude-code で行えます。"
    exit 0
fi

LAST_CHECK=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
DIFF=$(( (NOW - LAST_CHECK) / 86400 ))

if [ "$DIFF" -ge "$INTERVAL_DAYS" ]; then
    echo "前回の /setup-claude-code から${DIFF}日経っています。/setup-claude-code で最新状態を確認できます。"
fi
