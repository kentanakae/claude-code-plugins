---
name: edit-skill
description: Claude Codeスキルの作成・更新を公式仕様に基づいて行う。新しいスキル作成（create）や既存スキルの更新（update）時に使用。
argument-hint: [create|update] [skill-name]
allowed-tools: WebFetch, Read, Write, Edit, Glob, AskUserQuestion
---

## Step 1: サブコマンド判定

- `$ARGUMENTS[0]` が `create` → Step 3（新規作成フロー）へ
- `$ARGUMENTS[0]` が `update` → Step 4（更新フロー）へ
- 未指定 or 上記以外 → AskUserQuestion で create / update を選択させてから対応する Step へ

スキル名は `$ARGUMENTS[1]` から取得する。未指定の場合は各フロー内で確認する。

## Step 2: ドキュメント確認と差分チェック

WebFetchで <https://code.claude.com/docs/ja/skills.md> を取得し、「フロントマターリファレンス」テーブルの全フィールド名を抽出する。以下の既知フィールド一覧と比較し、差分があれば警告してこのスキル（edit-skill）のアップデートが必要な旨を伝える。差分がなければ次の Step に進む。

**既知フィールド:** `name`, `description`, `argument-hint`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `context`, `agent`, `hooks`

## Step 3: 新規作成フロー

### Step 3-1: スキル設計インタビュー

ユーザーに以下を確認する（AskUserQuestionを使用）:

#### 基本設定

1. **スキル名**:
   - `$ARGUMENTS[1]` が指定されている場合はそれを使用、なければインタビューで確認
   - 制約: 小文字、数字、ハイフンのみ（最大64文字）

2. **スキルタイプ**:
   - **リファレンス型**: 規約、パターン、スタイルガイドなどの知識を提供
   - **タスク型**: 特定のアクションを実行するステップバイステップ指示

3. **説明（description）**: **推奨**
   - スキルの用途、使用タイミング、関連キーワードを簡潔に記述する
   - Claudeはこの説明を使ってスキルを自動適用するか判断するため、ユーザーが自然に言うキーワードを含めること
   - 全スキルの説明が合計15,000文字の予算を共有してコンテキストに常時読み込まれるため、簡潔に保つ（文字数ベースのためトークン数は気にしなくてよい）
   - 技術用語は英語キーワードのまま含めるとマッチしやすい（例: code, deploy, test）
   - 例: "コードを図解と比喩で説明する。コードの仕組みの質問、コードベースの学習、「これはどう動く？」という質問時に使用。"
   - `disable-model-invocation: true` の場合、descriptionはコンテキストに載らないため、キーワードやトリガー文言は不要。用途の説明のみで十分
   - 省略時はマークダウンコンテンツの最初の段落が使用される

4. **引数ヒント（argument-hint）**: オプション
   - `/` メニューのオートコンプリート時に表示されるヒント
   - 例: `[issue-number]`、`[filename] [format]`

5. **適用範囲**:
   - 個人（~/.claude/skills/）- 全プロジェクトで利用可能
   - プロジェクト（.claude/skills/）- このプロジェクトのみ
   - モノレポではサブディレクトリ内の `.claude/skills/` からも自動検出される

#### 呼び出し制御

6. **呼び出し方法**:
   - **手動のみ**（`disable-model-invocation: true`）: ユーザーのみが `/skill-name` で呼び出し可能。副作用のあるワークフロー向け
   - **自動＋手動**（デフォルト）: Claudeが関連時に自動ロード、ユーザーも手動で呼び出し可能
   - **Claude専用**（`user-invocable: false`）: `/` メニューに非表示。バックグラウンド知識向け

#### 実行環境

7. **実行コンテキスト**:
   - **インライン**（デフォルト）: メイン会話内で実行。会話コンテキストにアクセス可能
   - **サブエージェント**（`context: fork`）: 分離されたコンテキストで実行。会話履歴にアクセス不可

8. **サブエージェントタイプ**（`context: fork` 時のみ）:
   - `Explore`（読み取り専用探索）/ `Plan`（設計・計画）/ `general-purpose`（デフォルト）/ カスタム（`.claude/agents/` で定義）

9. **モデル指定（model）**: オプション - スキル実行時に使用するモデルを指定

#### ツールとファイル

10. **必要なツール（allowed-tools）**: オプション
    - スキルがアクティブな時にClaudeが許可なく使用できるツール
    - 例: `Read, Grep, Glob`（読み取り専用）、`Bash(gh:*)`（GitHub CLI限定）

11. **サポートファイル構成**: オプション
    - SKILL.md以外に含めるファイル: テンプレート、例、スクリプト、リファレンスなど
    - SKILL.mdは500行以下を推奨。詳細は別ファイルに分離

12. **フック（hooks）**: オプション
    - スキルのライフサイクルにスコープされたフック。詳細は [Hooks](https://code.claude.com/docs/ja/hooks) を参照

### Step 3-2: 高度な機能確認（該当する場合のみ）

#### 拡張思考（ultrathink）

スキルで拡張思考を有効にしたい場合、SKILL.mdコンテンツ内のどこかに「ultrathink」という単語を含める。これにより、Claudeはより深い思考プロセスを使用してタスクを処理する。

#### 変数置換

スキルコンテンツ内で使用可能な変数:

| 変数 | 説明 |
|------|------|
| `$ARGUMENTS` | スキル呼び出し時に渡された全引数文字列。コンテンツに存在しない場合は末尾に `ARGUMENTS: <value>` として追加 |
| `$ARGUMENTS[N]` | N番目の引数（0始まり）。例: `$ARGUMENTS[0]` は最初の引数 |
| `$N` | `$ARGUMENTS[N]` の短縮形。`$1` は最初の引数、`$2` は2番目 |
| `${CLAUDE_SESSION_ID}` | 現在のセッションID。ログやセッション固有のファイル作成に有用 |

#### 動的コンテキスト注入

シェルコマンドの実行結果をスキルコンテンツに注入する機能。エクスクラメーションマーク（!）の直後にバッククォートで囲んだコマンドを記述する。これはプリプロセッシングとして動作し、Claudeが見る前にコマンド出力がプレースホルダーを置換する。

SKILL.md内にサンプルコードを記述するとパーサーが検出・実行するため、直接記述は避けること。詳細は [公式ドキュメント](https://code.claude.com/docs/ja/skills#inject-dynamic-context) を参照。

#### ビジュアル出力パターン

スクリプトをバンドルしてHTMLなどのビジュアル出力を生成可能:

```text
my-skill/
├── SKILL.md
└── scripts/
    └── visualize.py  # Claudeが実行するスクリプト
```

### Step 3-3: スキル作成実行

1. 指定されたディレクトリにスキルフォルダを作成
2. SKILL.mdファイルを生成
3. サポートファイルがある場合は作成
4. 作成したファイルの内容を表示

## Step 4: 更新フロー

### Step 4-1: 対象スキルの特定

- `$ARGUMENTS[1]` でスキル名が指定されている場合: 以下のパスを Glob で検索し SKILL.md を探す
  - `.claude/skills/*/SKILL.md`
  - `~/.claude/skills/*/SKILL.md`
  - `**/plugins/*/skills/*/SKILL.md`
- 未指定の場合: 上記すべてのパスからスキル一覧を収集し、AskUserQuestion で対象を選択させる

### Step 4-2: 現在の設定の読み込みと表示

対象の SKILL.md を Read で読み込み、以下を整理して表示する:

- **フロントマター設定一覧**: 各フィールドの現在値
- **本文概要**: 見出し構成と行数
- **サポートファイル一覧**: 同ディレクトリ内の SKILL.md 以外のファイル（Glob で検索）

### Step 4-3: 更新箇所の選択

AskUserQuestion（multiSelect: true）で更新したい箇所を選択させる:

- **フロントマター設定**（name, description, argument-hint, allowed-tools など）
- **本文（スキル指示内容）**
- **サポートファイル**（テンプレート、スクリプトなど）
- **高度な機能**（変数置換、動的コンテキスト注入、ultrathink など）

### Step 4-4: 選択項目の更新インタビュー

選択された項目について、現在の値を表示しながら変更内容を確認する:

- **フロントマター**: 各フィールドの現在値を提示し、変更したいフィールドのみ新しい値を確認。変更のない部分はそのまま保持
- **本文**: 現在の構成を示しつつ、具体的な変更指示を確認。全面書き換えか部分修正かを確認
- **サポートファイル**: 追加・変更・削除の対象を確認
- **高度な機能**: Step 3-2 のリファレンスを参照しながら、追加・変更する機能を確認

### Step 4-5: 更新実行

1. 変更内容のプレビューを表示（変更前 → 変更後の diff 形式）
2. AskUserQuestion で適用確認
3. 変更を反映:
   - フロントマターのみの変更 → Edit で部分更新
   - 本文の部分修正 → Edit で部分更新
   - 大幅な書き換え → Write で全体更新
   - サポートファイル → Write / Edit で個別に更新
4. 更新結果を表示

## フロントマターリファレンス

```yaml
---
name: my-skill                      # スキル名（省略時はディレクトリ名）
description: What this skill does   # 説明（推奨）
argument-hint: [arg1] [arg2]        # 引数ヒント
disable-model-invocation: true      # Claude自動呼び出し無効化
user-invocable: false               # /メニューから非表示
allowed-tools: Read, Grep, Glob     # 許可ツール
model: sonnet                       # 使用モデル
context: fork                       # サブエージェント実行
agent: Explore                      # サブエージェントタイプ
hooks:                              # ライフサイクルフック
  pre-tool-execution:
    - command: echo "Starting"
---
```

## 引数

- `/edit-skill create my-new-skill`: スキル名を指定して新規作成
- `/edit-skill create`: インタビューでスキル名を確認して新規作成
- `/edit-skill update my-existing-skill`: スキル名を指定して更新
- `/edit-skill update`: スキル一覧から選択して更新
- `/edit-skill`: サブコマンド選択から開始
