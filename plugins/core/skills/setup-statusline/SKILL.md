---
name: setup-statusline
description: カスタムステータスラインのインストール・アンインストール・設定変更を行う。
argument-hint: [install|update|uninstall]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

## Step 1: 引数判定

- `$ARGUMENTS` が `install` → Step 2（インストールフロー）へ
- `$ARGUMENTS` が `update` → Step 4（アップデートフロー）へ
- `$ARGUMENTS` が `uninstall` → Step 3（アンインストールフロー）へ
- 引数なし or 上記以外 → AskUserQuestion で install / update / uninstall を選択させてから対応する Step へ

## Step 2: インストールフロー

### 2-1. 設定先の選択

AskUserQuestion で以下から選択させる:

- `~/.claude/settings.json` （グローバル）
- `~/.claude/settings.local.json` （グローバル・ローカル）
- `.claude/settings.json` （プロジェクト）
- `.claude/settings.local.json` （プロジェクト・ローカル）

### 2-2. 表示項目の設定

AskUserQuestion（multiSelect: true）で表示項目を選択させる。各項目のデフォルト状態も明示すること:

| 項目 | ON フラグ | OFF フラグ | デフォルト |
|------|-----------|------------|------------|
| モデル名 | --show-model | --no-model | ON |
| Git ブランチ | --show-branch | --no-branch | ON |
| Dirty mark | --show-dirty | --no-dirty | ON |
| トークン使用量 | --show-usage | --no-usage | OFF |
| コスト | --show-cost | --no-cost | OFF |
| コンテキストバー | --show-bar | --no-bar | ON |

デフォルト ON の項目は「選択されている」状態として提示し、ユーザーが選択を外したものだけ `--no-xxx` フラグを付与する。
デフォルト OFF の項目はユーザーが選択したものだけ `--show-xxx` フラグを付与する。
デフォルト状態のままの項目にはフラグを付けない（冗長なフラグを避ける）。

### 2-3. statusline バイナリのインストール

Bash で `install` コマンドを使い、`${CLAUDE_PLUGIN_ROOT}/skills/setup-statusline/statusline` を `~/.claude/statusline` にコピーする。`install -m 755` でコピーと実行権限の付与を同時に行う。設定先に関わらず、コピー先は常に `~/.claude/statusline` に固定する。

### 2-4. 設定ファイルの編集

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

`<コピー先パス>` は常に `~/.claude/statusline` を使用する。
`<flags>` 部分はユーザーの選択に基づいて構成する。デフォルト値と異なる選択のみフラグを付与する。全てデフォルトの場合はフラグなし。

3. 既存の設定ファイルに他のキーがある場合はそれらを保持したまま `statusLine` のみ変更する。
4. Edit ツールで設定ファイルを更新する（新規ファイルの場合は Write を使用）。

### 2-5. 完了メッセージ

以下を表示する:
- 設定先のファイルパス
- 設定した `statusLine` の内容
- 「Claude Code を再起動すると反映されます」

## Step 3: アンインストールフロー

### 3-1. 設定先の特定

以下の4ファイルを Read で確認する（存在しない場合はスキップ）。`./.claude/` で始まるパスはカレントディレクトリからの相対パスなので、Read には絶対パスに変換して渡すこと。

- `~/.claude/settings.json`
- `~/.claude/settings.local.json`
- `./.claude/settings.json`
- `./.claude/settings.local.json`

それぞれの JSON に `statusLine` キーが存在するかチェックする。

- どちらにもなければ → 「ステータスラインは設定されていません」と表示して終了
- 片方のみにあれば → そのファイルを対象とする
- 両方にあれば → AskUserQuestion でどちらを削除するか（または両方か）を確認する

### 3-2. 設定ファイルの編集

対象の設定ファイルから `statusLine` キーとその値を削除する。他のキーは保持する。Edit ツールを使用する。

### 3-3. statusline バイナリの削除

`~/.claude/statusline` を Bash で `rm` コマンドを使い削除する。ファイルが存在しない場合はスキップする。

### 3-4. 完了メッセージ

以下を表示する:
- 削除したファイルパス

## Step 4: アップデートフロー

### 4-1. 既存設定の検出

以下の4ファイルを Read で確認する（存在しない場合はスキップ）。`./.claude/` で始まるパスはカレントディレクトリからの相対パスなので、Read には絶対パスに変換して渡すこと。

- `~/.claude/settings.json`
- `~/.claude/settings.local.json`
- `./.claude/settings.json`
- `./.claude/settings.local.json`

それぞれの JSON に `statusLine` キーが存在するかチェックする。

- どちらにもなければ → 「ステータスラインは設定されていません。先に `/setup-statusline install` を実行してください」と表示して終了
- 片方のみにあれば → そのファイルを対象とする
- 両方にあれば → AskUserQuestion でどちらを更新するか（または両方か）を確認する

### 4-2. 現在のフラグの解析

対象ファイルの `statusLine.command` の値からフラグ部分を解析し、各項目の現在の状態を特定する:

| 項目 | ON フラグ | OFF フラグ | デフォルト |
|------|-----------|------------|------------|
| モデル名 | --show-model | --no-model | ON |
| Git ブランチ | --show-branch | --no-branch | ON |
| Dirty mark | --show-dirty | --no-dirty | ON |
| トークン使用量 | --show-usage | --no-usage | OFF |
| コスト | --show-cost | --no-cost | OFF |
| コンテキストバー | --show-bar | --no-bar | ON |

フラグが明示されていない項目はデフォルト状態とみなす。

### 4-3. 表示項目の再設定

AskUserQuestion（multiSelect: true）で表示項目を選択させる。**現在の設定状態**（4-2 で解析した結果）をデフォルトの選択状態として提示すること。

### 4-4. statusline バイナリの更新

Step 2-3 と同じ要領で、`install -m 755` を使い `${CLAUDE_PLUGIN_ROOT}/skills/setup-statusline/statusline` を `~/.claude/statusline` にインストールする。

### 4-5. 設定ファイルの更新

Step 2-4 と同じ要領で `statusLine` を更新する。コマンドパスも含めて全体を書き換える:

```json
{
  "statusLine": {
    "type": "command",
    "command": "<コピー先パス> <flags>",
    "padding": 0
  }
}
```

`<コピー先パス>` は常に `~/.claude/statusline` を使用する。
`<flags>` 部分はユーザーの選択に基づいて構成する。デフォルト値と異なる選択のみフラグを付与する。全てデフォルトの場合はフラグなし。

### 4-6. 完了メッセージ

以下を表示する:
- 更新したファイルパス
- 設定した `statusLine` の内容
- 「Claude Code を再起動すると反映されます」
