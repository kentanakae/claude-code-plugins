---
name: edit-hook
description: Claude Code hooksの作成・更新を公式仕様に基づいて行う。新しいhook作成（create）や既存hookの更新（update）時に使用。
argument-hint: [create|update]
disable-model-invocation: true
allowed-tools: WebFetch, Read, Write, Edit, Glob
---

## Step 0: プランモード解除

プランモードが有効な場合は、ExitPlanMode ツールを呼び出して解除してください。 プランモードでない場合はこのステップをスキップしてください。

## Step 1: サブコマンド判定

- `$ARGUMENTS[0]` が `create` → Step 3（新規作成フロー）へ
- `$ARGUMENTS[0]` が `update` → Step 4（更新フロー）へ
- 未指定 or 上記以外 → AskUserQuestion で create / update を選択させてから対応する Step へ

## Step 2: ドキュメント確認と差分チェック

WebFetchで <https://code.claude.com/docs/ja/hooks.md> を取得し、フックイベント一覧テーブルから全イベント名を抽出する。以下の既知イベント一覧と比較し、差分があれば警告してこのスキル（edit-hook）のアップデートが必要な旨を伝える。差分がなければ次の Step に進む。

**既知イベント:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `SubagentStop`, `Stop`, `TeammateIdle`, `TaskCompleted`, `InstructionsLoaded`, `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `SessionEnd`

**既知ハンドラータイプ:** `command`, `http`, `prompt`, `agent`

## Step 3: 新規作成フロー

### Step 3-1: フック設計インタビュー

ユーザーに以下を確認する（AskUserQuestionを使用）:

1. **フックの目的**: 何を自動化・制御したいか（自由記述で確認）

2. **フックイベント**: どのライフサイクルポイントで発火するか
   - 詳細は [./references/hooks.md](./references/hooks.md) の「フックイベント一覧」を参照

3. **マッチャー**: イベントのフィルタリング条件（該当イベントがマッチャーをサポートする場合）
   - 詳細は [./references/hooks.md](./references/hooks.md) の「マッチャーパターン」を参照

4. **ハンドラータイプ**: 実行するハンドラーの種類
   - `command`: シェルコマンド実行（最も一般的）
   - `http`: HTTP POSTリクエスト送信
   - `prompt`: LLMプロンプト評価（単一ターン）
   - `agent`: サブエージェント起動（ツール使用可能）

5. **ハンドラー詳細**: タイプに応じた設定
   - command: 実行するコマンド、非同期実行の有無
   - http: URL、ヘッダー、許可する環境変数
   - prompt/agent: プロンプトテキスト、モデル指定
   - 共通: タイムアウト、ステータスメッセージ

6. **設定ファイルの場所**:
   - ユーザー設定（`~/.claude/settings.json`）- 全プロジェクトに適用
   - プロジェクト設定（`.claude/settings.json`）- このプロジェクトのみ、リポジトリにコミット可能
   - ローカル設定（`.claude/settings.local.json`）- このプロジェクトのみ、gitignored

7. **フックスクリプトが必要か**: コマンドハンドラーの場合、インラインコマンドか外部スクリプトか
   - インライン: 単純なワンライナー（`echo`, `jq` 等）
   - 外部スクリプト: 複雑なロジック → `.claude/hooks/` にスクリプトファイルを作成

### Step 3-2: フックスクリプト作成（必要な場合）

外部スクリプトが必要な場合:

1. `.claude/hooks/` ディレクトリにスクリプトファイルを作成
2. スクリプトの内容:
   - stdin から JSON 入力を読み取る（`jq` 等で解析）
   - 必要なロジックを実行
   - 必要に応じて stdout に JSON 出力を返す
   - 適切な終了コードを返す（0: 成功、2: ブロック）
3. 実行権限を付与（`chmod +x`）

スクリプト作成時の参照情報:
- JSON入力フィールドは [./references/hooks.md](./references/hooks.md) の「共通入力フィールド」と各イベントの入力セクションを参照
- JSON出力形式は [./references/hooks.md](./references/hooks.md) の「JSON出力」セクションを参照
- 終了コードの動作は [./references/hooks.md](./references/hooks.md) の「終了コード」セクションを参照

### Step 3-3: 設定ファイルへの登録

1. 対象の settings.json を Read で読み込む（存在しない場合は新規作成）
2. `hooks` キー配下に新しいフック設定を追加
3. 既存の hooks 設定がある場合はマージ（既存設定を壊さない）
4. Edit または Write で settings.json を更新

**設定構造:**

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<pattern>",
        "hooks": [
          {
            "type": "command",
            "command": "<command-or-script-path>",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

### Step 3-4: 動作確認案内

作成完了後、以下を案内する:
- フックは次回のセッション開始時から有効になる（セッション中の変更は `/hooks` メニューでレビューが必要）
- `/hooks` メニューでフックの確認・管理が可能
- 詳細モード（`Ctrl+O`）でフック実行ログを確認可能

## Step 4: 更新フロー

### Step 4-1: 対象フックの特定

以下の設定ファイルを Glob と Read で検索し、既存の hooks 設定を収集する:
- `~/.claude/settings.json`
- `.claude/settings.json`
- `.claude/settings.local.json`

全ての設定ファイルから hooks セクションを読み取り、登録されているフック一覧を表示する。AskUserQuestion で更新対象を選択させる。

### Step 4-2: 現在の設定の読み込みと表示

対象フックについて以下を整理して表示する:

- **設定ファイル**: どのファイルに定義されているか
- **イベント**: フックイベント名
- **マッチャー**: フィルタリング条件
- **ハンドラー一覧**: 各ハンドラーのタイプ・コマンド・設定
- **関連スクリプト**: 外部スクリプトがある場合はその内容も表示

### Step 4-3: 更新箇所の選択

AskUserQuestion（multiSelect: true）で更新したい箇所を選択させる:

- **イベント・マッチャー**: フックイベントやマッチャーパターンの変更
- **ハンドラー設定**: コマンド、URL、タイムアウト等の変更
- **フックスクリプト**: 外部スクリプトの内容変更
- **フックの追加**: 同じイベントに新しいハンドラーを追加
- **フックの削除**: 既存ハンドラーの削除

### Step 4-4: 選択項目の更新インタビュー

選択された項目について、現在の値を表示しながら変更内容を確認する。

### Step 4-5: 更新実行

1. 変更内容のプレビューを表示（変更前 → 変更後の diff 形式）
2. AskUserQuestion で適用確認
3. 変更を反映:
   - settings.json の変更 → Edit で部分更新
   - スクリプトの変更 → Edit で部分更新、大幅変更は Write
4. 更新結果を表示

## フックイベントクイックリファレンス

| イベント | 発火タイミング | マッチャー |
|---|---|---|
| `PreToolUse` | ツール実行前 | ツール名 |
| `PostToolUse` | ツール成功後 | ツール名 |
| `PostToolUseFailure` | ツール失敗後 | ツール名 |
| `PermissionRequest` | 権限ダイアログ表示時 | ツール名 |
| `UserPromptSubmit` | プロンプト送信時 | なし |
| `Stop` | Claude応答完了時 | なし |
| `SessionStart` | セッション開始時 | startup/resume/clear/compact |
| `SessionEnd` | セッション終了時 | clear/logout/prompt_input_exit/other |
| `SubagentStart` | サブエージェント起動時 | エージェントタイプ |
| `SubagentStop` | サブエージェント完了時 | エージェントタイプ |
| `Notification` | 通知送信時 | 通知タイプ |
| `TeammateIdle` | チームメイトアイドル時 | なし |
| `TaskCompleted` | タスク完了時 | なし |
| `InstructionsLoaded` | CLAUDE.md読込時 | なし |
| `ConfigChange` | 設定変更時 | 設定ソース |
| `WorktreeCreate` | ワークツリー作成時 | なし |
| `WorktreeRemove` | ワークツリー削除時 | なし |
| `PreCompact` | コンパクション前 | manual/auto |

詳細なリファレンス情報は [./references/hooks.md](./references/hooks.md) を参照。

## 引数

- `/edit-hook create`: 新しいフックを作成
- `/edit-hook update`: 既存フックを更新
- `/edit-hook`: サブコマンド選択から開始
