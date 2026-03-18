# Hooks リファレンス

Claude Code hooks の設定に必要な詳細リファレンス。

## 設定ファイルの場所

| 場所 | パス | スコープ | 共有 |
|---|---|---|---|
| ユーザー設定 | `~/.claude/settings.json` | 全プロジェクト | いいえ |
| プロジェクト設定 | `.claude/settings.json` | 単一プロジェクト | はい（リポジトリにコミット可） |
| ローカル設定 | `.claude/settings.local.json` | 単一プロジェクト | いいえ（gitignored） |
| プラグイン | `<plugin>/hooks/hooks.json` | プラグイン有効時 | はい |
| スキル/エージェント | フロントマター内 `hooks:` | コンポーネントアクティブ時 | はい |

## 設定構造

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<regex-pattern>",
        "hooks": [
          {
            "type": "command",
            "command": "script.sh",
            "timeout": 60,
            "statusMessage": "Running check...",
            "async": false
          }
        ]
      }
    ]
  }
}
```

3つのネストレベル:
1. **フックイベント**: ライフサイクルポイント（`PreToolUse`, `PostToolUse` 等）
2. **マッチャーグループ**: 発火条件のフィルター（正規表現）
3. **フックハンドラー**: 実行するコマンド/HTTP/プロンプト/エージェント

## フックイベント一覧

### SessionStart

セッション開始・再開時に発火。

- **マッチャー**: `startup`, `resume`, `clear`, `compact`
- **入力**: `source`, `model`, `agent_type`（オプション）
- **決定制御**: stdout テキストが Claude のコンテキストに追加。`additionalContext` フィールドも使用可
- **特殊**: `CLAUDE_ENV_FILE` で環境変数を永続化可能

### UserPromptSubmit

ユーザープロンプト送信時、Claude 処理前に発火。

- **マッチャー**: なし（常に発火）
- **入力**: `prompt`（送信テキスト）
- **決定制御**: `decision: "block"` でプロンプトをブロック。stdout テキストがコンテキストに追加

### PreToolUse

ツール実行前に発火。ツール呼び出しの許可/拒否/変更が可能。

- **マッチャー**: ツール名（`Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `Agent`, `WebFetch`, `WebSearch`, `mcp__<server>__<tool>`）
- **入力**: `tool_name`, `tool_input`, `tool_use_id`
- **決定制御**: `hookSpecificOutput` で制御
  - `permissionDecision`: `"allow"` / `"deny"` / `"ask"`
  - `permissionDecisionReason`: 理由テキスト
  - `updatedInput`: ツール入力の変更
  - `additionalContext`: 追加コンテキスト

### PermissionRequest

権限ダイアログ表示時に発火。ユーザーに代わって許可/拒否が可能。

- **マッチャー**: ツール名（PreToolUse と同じ）
- **入力**: `tool_name`, `tool_input`, `permission_suggestions`
- **決定制御**: `hookSpecificOutput.decision` で制御
  - `behavior`: `"allow"` / `"deny"`
  - `updatedInput`: ツール入力の変更（allow時）
  - `updatedPermissions`: 権限ルール更新（allow時）
  - `message`: 拒否理由（deny時）

### PostToolUse

ツール正常完了後に発火。

- **マッチャー**: ツール名
- **入力**: `tool_name`, `tool_input`, `tool_response`, `tool_use_id`
- **決定制御**: `decision: "block"` + `reason` でフィードバック

### PostToolUseFailure

ツール失敗後に発火。

- **マッチャー**: ツール名
- **入力**: `tool_name`, `tool_input`, `tool_error`, `tool_use_id`
- **決定制御**: PostToolUse と同じ

### Notification

通知送信時に発火。

- **マッチャー**: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`
- **入力**: `type`, `message`, `title`
- **決定制御**: なし（副作用のみ）

### SubagentStart

サブエージェント起動時に発火。

- **マッチャー**: エージェントタイプ（`Bash`, `Explore`, `Plan`, カスタム名）
- **入力**: `agent_type`, `agent_prompt`, `model`
- **決定制御**: なし（副作用のみ）

### SubagentStop

サブエージェント完了時に発火。

- **マッチャー**: エージェントタイプ（SubagentStart と同じ）
- **入力**: `agent_type`, `agent_result`
- **決定制御**: `decision: "block"` でサブエージェント停止を防止

### Stop

Claude 応答完了時に発火。

- **マッチャー**: なし（常に発火）
- **入力**: `stop_reason`
- **決定制御**: `decision: "block"` で停止を防止し会話を続行

### TeammateIdle

チームメイトがアイドル状態になる前に発火。

- **マッチャー**: なし（常に発火）
- **決定制御**: 終了コード 2 でアイドル移行を防止

### TaskCompleted

タスク完了マーク時に発火。

- **マッチャー**: なし（常に発火）
- **決定制御**: 終了コード 2 で完了を防止

### InstructionsLoaded

CLAUDE.md や `.claude/rules/*.md` がコンテキストに読み込まれた時に発火。

- **入力**: ファイル情報
- **決定制御**: なし

### ConfigChange

設定ファイル変更時に発火。

- **マッチャー**: `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills`
- **決定制御**: `decision: "block"` で変更の適用をブロック

### WorktreeCreate

ワークツリー作成時に発火。デフォルトの git 動作を置換。

- **マッチャー**: なし（常に発火）
- **決定制御**: stdout にワークツリーの絶対パスを出力。非0終了で作成失敗

### WorktreeRemove

ワークツリー削除時に発火。

- **マッチャー**: なし（常に発火）
- **決定制御**: なし（副作用のみ）

### PreCompact

コンテキストコンパクション前に発火。

- **マッチャー**: `manual`, `auto`
- **決定制御**: なし（副作用のみ）

### SessionEnd

セッション終了時に発火。

- **マッチャー**: `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`
- **決定制御**: なし（副作用のみ）

## ハンドラータイプ

### 共通フィールド

| フィールド | 必須 | 説明 |
|---|---|---|
| `type` | はい | `"command"`, `"http"`, `"prompt"`, `"agent"` |
| `timeout` | いいえ | タイムアウト秒数（デフォルト: command=600, prompt=30, agent=60） |
| `statusMessage` | いいえ | 実行中に表示するスピナーメッセージ |
| `once` | いいえ | `true` でセッションごとに1回のみ実行（スキルのみ） |

### command ハンドラー

| フィールド | 必須 | 説明 |
|---|---|---|
| `command` | はい | 実行するシェルコマンド |
| `async` | いいえ | `true` でバックグラウンド実行 |

### http ハンドラー

| フィールド | 必須 | 説明 |
|---|---|---|
| `url` | はい | POST リクエスト送信先 URL |
| `headers` | いいえ | 追加 HTTP ヘッダー（`$VAR_NAME` で環境変数補間可） |
| `allowedEnvVars` | いいえ | ヘッダーで使用可能な環境変数名リスト |

### prompt / agent ハンドラー

| フィールド | 必須 | 説明 |
|---|---|---|
| `prompt` | はい | モデルに送信するプロンプト（`$ARGUMENTS` でフック入力JSONを参照） |
| `model` | いいえ | 使用モデル（デフォルトは高速モデル） |

## 共通入力フィールド

全フックイベントの JSON 入力に含まれるフィールド:

| フィールド | 説明 |
|---|---|
| `session_id` | セッション識別子 |
| `transcript_path` | 会話 JSON ファイルパス |
| `cwd` | 現在の作業ディレクトリ |
| `permission_mode` | 権限モード（`default`, `plan`, `acceptEdits`, `dontAsk`, `bypassPermissions`） |
| `hook_event_name` | 発火イベント名 |

## JSON 出力

### ユニバーサルフィールド（全イベント共通）

| フィールド | デフォルト | 説明 |
|---|---|---|
| `continue` | `true` | `false` で Claude を完全停止 |
| `stopReason` | なし | `continue: false` 時のユーザー向けメッセージ |
| `suppressOutput` | `false` | `true` で詳細モード出力を非表示 |
| `systemMessage` | なし | ユーザーに表示する警告メッセージ |

### 決定制御パターン

| イベント | パターン | キーフィールド |
|---|---|---|
| UserPromptSubmit, PostToolUse, PostToolUseFailure, Stop, SubagentStop, ConfigChange | トップレベル `decision` | `decision: "block"`, `reason` |
| TeammateIdle, TaskCompleted | 終了コードのみ | exit 2 でブロック |
| PreToolUse | `hookSpecificOutput` | `permissionDecision` (allow/deny/ask) |
| PermissionRequest | `hookSpecificOutput` | `decision.behavior` (allow/deny) |
| WorktreeCreate | stdout パス | ワークツリーの絶対パスを出力 |

## 終了コード

| コード | 意味 | 動作 |
|---|---|---|
| 0 | 成功 | stdout の JSON を解析して処理 |
| 2 | ブロッキングエラー | stderr を Claude にフィードバック（イベントにより動作が異なる） |
| その他 | ノンブロッキングエラー | stderr を詳細モードで表示、実行は続行 |

## 環境変数

| 変数 | 説明 |
|---|---|
| `$CLAUDE_PROJECT_DIR` | プロジェクトルート |
| `${CLAUDE_PLUGIN_ROOT}` | プラグインルートディレクトリ |
| `$CLAUDE_ENV_FILE` | 環境変数永続化ファイル（SessionStart のみ） |
| `$CLAUDE_CODE_REMOTE` | リモート Web 環境で `"true"` |

## 設定例

### 破壊的コマンドをブロック

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/block-rm.sh"
          }
        ]
      }
    ]
  }
}
```

### ファイル変更後にリント実行

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/lint-check.sh"
          }
        ]
      }
    ]
  }
}
```

### セッション開始時にコンテキスト追加

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Current branch:' $(git branch --show-current)"
          }
        ]
      }
    ]
  }
}
```

### プロンプトベースのフック（LLM評価）

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "The following bash command is about to be executed. Is it safe? If not, deny it. Command: $ARGUMENTS"
          }
        ]
      }
    ]
  }
}
```

### HTTP フック

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:8080/hooks/validate",
            "timeout": 30,
            "headers": {
              "Authorization": "Bearer $MY_TOKEN"
            },
            "allowedEnvVars": ["MY_TOKEN"]
          }
        ]
      }
    ]
  }
}
```

### フックの無効化

```json
{
  "disableAllHooks": true
}
```
