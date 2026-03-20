---
name: setup-statusline
description: カスタムステータスラインのインストール・アンインストール・設定変更を行う。
argument-hint: [install|update|uninstall]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash
---

## Step 0: プランモード解除

プランモードが有効な場合は、ExitPlanMode ツールを呼び出して解除してください。 プランモードでない場合はこのステップをスキップしてください。

## Step 1: 引数判定

- `$ARGUMENTS` が `install` → Step 2（インストールフロー）へ
- `$ARGUMENTS` が `update` → Step 4（アップデートフロー）へ
- `$ARGUMENTS` が `uninstall` → Step 3（アンインストールフロー）へ
- 引数なし or 上記以外 → AskUserQuestion で install / update / uninstall を選択させてから対応する Step へ

## 共通ルール

### 共通手順 A: statusLine の存否チェック（4ファイル）

以下の4ファイルを Read で読み込み、`statusLine` キーの存否をチェックする（ファイルが存在しない場合はスキップ）。`./.claude/` で始まるパスはカレントディレクトリからの相対パスなので、Read には絶対パスに変換して渡すこと。

- `~/.claude/settings.json`
- `~/.claude/settings.local.json`
- `./.claude/settings.json`
- `./.claude/settings.local.json`

### 共通手順 B: statusLine の書き込み

`<コピー先パス>` は常に `~/.claude/statusline` を使用する。
`<flags>` 部分は Step 2-2 のルールに従い、全項目に ON/OFF フラグを明示的に付与する。

1. 対象の設定ファイルを Read で読み込む。ファイルが存在しない場合は `{}` として扱う。
2. JSON をパースし、`statusLine` キーを以下の形式で追加または更新する:

```json
{
  "statusLine": {
    "type": "command",
    "command": "<コピー先パス> <flags>",
    "padding": 0
  }
}
```

3. 既存の設定ファイルに他のキーがある場合はそれらを保持したまま `statusLine` のみ変更する。
4. Edit ツールで設定ファイルを更新する（新規ファイルの場合は Write を使用）。

## Step 2: インストールフロー

### 2-1. 設定先の選択

AskUserQuestion で以下から選択させる:

- `~/.claude/settings.json` （グローバル）
- `~/.claude/settings.local.json` （グローバル・ローカル）
- `.claude/settings.json` （プロジェクト）
- `.claude/settings.local.json` （プロジェクト・ローカル）

### 2-2. 表示項目の設定

AskUserQuestion（multiSelect: true）で表示項目を選択させる。AskUserQuestion は1つの質問につき最大4選択肢のため、**2つの質問に分割して1回の AskUserQuestion で同時に送信する**。

**質問1（基本情報）:**

| 項目 | ON フラグ | OFF フラグ |
|------|-----------|------------|
| プロジェクトパス | --show-project | --no-project |
| モデル名 | --show-model | --no-model |
| Git ブランチ | --show-branch | --no-branch |
| Dirty mark | --show-dirty | --no-dirty |

**質問2（表示・メトリクス）:**

| 項目 | ON フラグ | OFF フラグ |
|------|-----------|------------|
| コンテキストバー | --show-bar | --no-bar |
| トークン使用量 | --show-usage | --no-usage |
| コスト | --show-cost | --no-cost |
| レート制限 | --show-rate | --no-rate |

全ての項目を未選択の状態で提示する。ユーザーが選択した項目に ON フラグを、選択しなかった項目に OFF フラグを付与する。

#### レート制限の詳細設定

レート制限を ON にした場合、**続けて別の AskUserQuestion** でレート制限のバー長を確認する:

**バーの長さ**（フラグ: `--rate-bar-length <n>`、デフォルト: 5）
- 選択肢: `3`, `5 (デフォルト)`, `10`
- ユーザーは「Other」で任意の数値も入力可能

デフォルト値と異なる値が選択された場合のみフラグを付与する。

### 2-3. バイナリのインストール

Bash で `install` コマンドを使い、`${CLAUDE_PLUGIN_ROOT}/skills/setup-statusline/statusline` を `~/.claude/statusline` にコピーする。`install -m 755` でコピーと実行権限の付与を同時に行う。

### 2-4. 設定ファイルの編集

共通手順 B に従い、ユーザーの選択に基づいて `statusLine` を書き込む。

### 2-5. 完了メッセージ

以下を表示する:
- 設定先のファイルパス
- 設定した `statusLine` の内容

## Step 3: アンインストールフロー

### 3-1. 設定先の特定

共通手順 A を実行する。

- どのファイルにもなければ → 「ステータスラインは設定されていません」と表示して終了
- 1ファイルのみにあれば → そのファイルを対象とする
- 複数にあれば → AskUserQuestion でどれを削除するか（または全てか）を確認する

### 3-2. 設定ファイルの編集

対象の設定ファイルから `statusLine` キーとその値を Edit で削除する。他のキーは保持する。

### 3-3. バイナリとレガシーファイルの削除

Bash で以下を実行する（存在しない場合はスキップ）:

1. `rm -f ~/.claude/statusline`
2. `launchctl unload ~/Library/LaunchAgents/com.claude-code.refresh-auth.plist 2>/dev/null || true`
3. `rm -f ~/Library/LaunchAgents/com.claude-code.refresh-auth.plist`
4. `rm -f ~/.claude/refresh-claude-auth`
5. `rm -f /tmp/claude-rate-limit-cache.json`

### 3-4. 完了メッセージ

以下を表示する:
- 削除したファイルパス

## Step 4: アップデートフロー

### 4-1. 既存設定の検出

共通手順 A を実行する。

- どのファイルにもなければ → 「ステータスラインは設定されていません。先に `/setup-statusline install` を実行してください」と表示して終了
- 1ファイルのみにあれば → そのファイルを対象とする
- 複数にあれば → AskUserQuestion でどれを更新するか（または全てか）を確認する

### 4-2. 現在のフラグの解析

対象ファイルの `statusLine.command` の値からフラグ部分を解析し、各項目の現在の状態を特定する。

#### フラグ解析

対象の設定ファイルを Read で読み込み、`statusLine.command` の値からフラグ部分を解析する。

| 項目 | ON フラグ | OFF フラグ |
|------|-----------|------------|
| プロジェクトパス | --show-project | --no-project |
| モデル名 | --show-model | --no-model |
| Git ブランチ | --show-branch | --no-branch |
| Dirty mark | --show-dirty | --no-dirty |
| コンテキストバー | --show-bar | --no-bar |
| トークン使用量 | --show-usage | --no-usage |
| コスト | --show-cost | --no-cost |
| レート制限 | --show-rate | --no-rate |

フラグが明示されていない項目は OFF とみなす。

レート制限が ON の場合、以下の値フラグも解析する:

| 項目 | フラグ | デフォルト値 |
|------|--------|-------------|
| バーの長さ | `--rate-bar-length <n>` | 5 |

フラグが明示されていない場合はデフォルト値とみなす。

### 4-3. 表示項目の再設定

Step 2-2 と同じ形式で、AskUserQuestion（multiSelect: true）を使い表示項目を選択させる。ただし以下の点が異なる:

- 各項目のラベルに **「現在: ON/OFF」** と表記し、4-2 で解析した現在の設定状態を反映すること。
- 現在 ON の項目は「選択されている」状態、OFF の項目は「選択されていない」状態として提示する（Step 2-2 では全て未選択だが、ここでは現在の状態を初期値とする）。

レート制限を ON にした場合、Step 2-2 と同じ形式でレート制限のバー長を確認する。ただし選択肢には **4-2 で解析した現在の設定値** を明示すること。

### 4-4. バイナリの更新

Step 2-3 と同じ要領で、`install -m 755` を使い `${CLAUDE_PLUGIN_ROOT}/skills/setup-statusline/statusline` を `~/.claude/statusline` にインストールする。

### 4-5. 設定ファイルの更新

共通手順 B に従い、ユーザーの選択に基づいて `statusLine` を更新する。コマンドパスも含めて全体を書き換える。

### 4-6. 完了メッセージ

以下を表示する:
- 更新したファイルパス
- 設定した `statusLine` の内容
