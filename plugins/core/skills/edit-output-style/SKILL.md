---
name: edit-output-style
description: Claude Code output styleの作成・更新を公式仕様に基づいて行う。新しいoutput style作成（create）や既存output styleの更新（update）時に使用。
argument-hint: [create|update] [style-name]
disable-model-invocation: true
allowed-tools: WebFetch, Read, Write, Edit, Glob, AskUserQuestion
---

## Step 1: サブコマンド判定

- `$ARGUMENTS[0]` が `create` → Step 3（新規作成フロー）へ
- `$ARGUMENTS[0]` が `update` → Step 4（更新フロー）へ
- 未指定 or 上記以外 → AskUserQuestion で create / update を選択させてから対応する Step へ

スタイル名は `$ARGUMENTS[1]` から取得する。未指定の場合は各フロー内で確認する。

## Step 2: ドキュメント確認と差分チェック

WebFetchで <https://code.claude.com/docs/ja/output-styles.md> を取得し、フロントマターリファレンスのテーブルから全フィールド名を抽出する。以下の既知フィールド一覧と比較し、差分があれば警告してこのスキル（edit-output-style）のアップデートが必要な旨を伝える。差分がなければ次の Step に進む。

**既知フィールド:** `name`, `description`, `keep-coding-instructions`

## Step 3: 新規作成フロー

### Step 3-1: スタイル設計インタビュー

ユーザーに以下を確認する（AskUserQuestionを使用）:

1. **スタイル名（ファイル名）**:
   - `$ARGUMENTS[1]` が指定されている場合はそれを使用、なければインタビューで確認
   - 制約: 小文字、数字、ハイフンのみ（ファイル名として有効な形式）
   - このファイル名が `/output-style <name>` での切り替えコマンドになる

2. **表示名（name）**: オプション
   - `/output-style` メニューに表示される名前
   - 省略時はファイル名から自動継承

3. **説明（description）**: 推奨
   - `/output-style` UIメニューに表示される説明
   - スタイルの目的・特徴を簡潔に記述

4. **コーディング指示の保持（keep-coding-instructions）**:
   - `true`: Claude Codeのデフォルトのコーディング関連システムプロンプトを保持。ソフトウェア開発用途向け
   - `false`（デフォルト）: コーディング関連の指示を除外。ソフトウェア開発以外の用途向け

5. **適用範囲**:
   - 個人（`~/.claude/output-styles/`）- 全プロジェクトで利用可能
   - プロジェクト（`.claude/output-styles/`）- このプロジェクトのみ

6. **スタイルの方向性**:
   - ユーザーにどのようなスタイルを望むか自由記述で確認
   - トーン（フォーマル/カジュアル等）、構造（箇条書き重視/文章重視等）、特殊な要件など

### Step 3-2: スタイル内容の作成

ユーザーの回答をもとに、output styleのマークダウンを作成する。

**Output Style の仕組み（作成時の重要な注意点）:**
- Output styleはClaude Codeのシステムプロンプトを直接変更する
- すべてのoutput styleで「効率的な出力」の指示（簡潔な応答など）が除外される
- カスタムoutput styleでは、`keep-coding-instructions: true` でない限り、コーディング関連の指示も除外される
- スタイルの指示内容はシステムプロンプトの末尾に追加される
- スタイル指示を遵守するリマインダーが会話中に自動的に追加される

### Step 3-3: スタイル作成実行

1. 指定されたディレクトリにマークダウンファイル（`<style-name>.md`）を作成
2. 作成したファイルの内容を表示
3. `/output-style <style-name>` で切り替え可能であることを案内

## Step 4: 更新フロー

### Step 4-1: 対象スタイルの特定

- `$ARGUMENTS[1]` でスタイル名が指定されている場合: 以下のパスを Glob で検索
  - `.claude/output-styles/*.md`
  - `~/.claude/output-styles/*.md`
- 未指定の場合: 上記すべてのパスからスタイル一覧を収集し、AskUserQuestion で対象を選択させる

### Step 4-2: 現在の設定の読み込みと表示

対象のファイルを Read で読み込み、以下を整理して表示する:

- **フロントマター設定一覧**: 各フィールドの現在値
- **本文概要**: 見出し構成と行数

### Step 4-3: 更新箇所の選択

AskUserQuestion（multiSelect: true）で更新したい箇所を選択させる:

- **フロントマター設定**（name, description, keep-coding-instructions）
- **本文（スタイル指示内容）**

### Step 4-4: 選択項目の更新インタビュー

選択された項目について、現在の値を表示しながら変更内容を確認する:

- **フロントマター**: 各フィールドの現在値を提示し、変更したいフィールドのみ新しい値を確認。変更のない部分はそのまま保持
- **本文**: 現在の構成を示しつつ、具体的な変更指示を確認。全面書き換えか部分修正かを確認

### Step 4-5: 更新実行

1. 変更内容のプレビューを表示（変更前 → 変更後の diff 形式）
2. AskUserQuestion で適用確認
3. 変更を反映:
   - フロントマターのみの変更 → Edit で部分更新
   - 本文の部分修正 → Edit で部分更新
   - 大幅な書き換え → Write で全体更新
4. 更新結果を表示

## フロントマターリファレンス

```yaml
---
name: my-style                  # スタイル名（省略時はファイル名から自動継承）
description: What this does      # 説明（/output-style UIに表示）
keep-coding-instructions: true   # コーディング関連の指示を保持するか（デフォルト: false）
---
```

## 引数

- `/edit-output-style create my-new-style`: スタイル名を指定して新規作成
- `/edit-output-style create`: インタビューでスタイル名を確認して新規作成
- `/edit-output-style update my-existing-style`: スタイル名を指定して更新
- `/edit-output-style update`: スタイル一覧から選択して更新
- `/edit-output-style`: サブコマンド選択から開始
