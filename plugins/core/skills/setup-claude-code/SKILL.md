---
name: setup-claude-code
description: Claude Code設定の監査・更新・バージョンチェック。設定の健全性チェック、新機能の確認、改善提案を行う。
user-invocable: true
argument-hint: "[audit|version|suggest|update|all]"
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, Write, Edit, Agent
---

# 設定の監査・更新スキル

あなたは Claude Code の設定監査員である。ユーザーの設定を点検し、診断し、改善するのが仕事。

$ARGUMENTS に基づいて該当するセクションを実行すること（デフォルトは "all"）。

## 1. バージョン確認（`version` または `all`）

`claude --version` で現在のバージョンを取得する。

Claude Code はネイティブアプリ。情報源は2つ:

### A. CHANGELOG — 何が変わったか
1. WebFetch で取得: `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`
2. 現在のバージョンより新しいエントリを探す
3. 変更内容をまとめる（新機能、破壊的変更、改善）

### B. Docs — 今何が使えるか
1. WebSearch で `site:docs.anthropic.com claude code` を検索し、ドキュメントのメインページを見つける
2. 該当ページを取得して、Claude Code の**全ての機能カテゴリ**を把握する
3. ユーザーの現在の設定（settings.json, skills, agents, hooks, rules, MCP 等）と比較する
4. **Docs に記載があるのにユーザーが使っていない機能**を特定する

### レポート内容
- 現在のバージョン vs 最新バージョン
- CHANGELOG: 現在のバージョン以降の主な変更点（古い場合）
- Docs vs 設定のギャップ: 利用可能だが未設定の機能
- 各ギャップについて、何ができるかを簡潔に説明し、設定するか確認する

## 2. 設定の監査（`audit` または `all`）

以下の**全項目**を確認し、状態を報告すること:

### シンボリックリンクの確認
**重要:** このユーザーは CLAUDE.md、skills/、rules/、agents/ 等をシンボリックリンクで管理していることがある。
各ファイル・ディレクトリを確認する際は `ls -la` でシンボリックリンクかどうかも確認し、リンク先を報告すること。
シンボリックリンク先が存在しない（リンク切れ）場合は警告すること。
また、`AGENTS.md` が `CLAUDE.md` としてシンボリックリンクされているパターンも正常として扱うこと。

### グローバル設定（`~/.claude/settings.json`）
- 現在の permissions を要約（allow/deny/ask の件数）
- 広すぎる権限や、追加すると便利な権限がないか確認
- `autoMemoryEnabled` が有効か確認
- `effortLevel`、`language` 等の動作設定を確認

### CLAUDE.md ファイル
- `~/.claude/CLAUDE.md`（グローバル）を確認
- `./CLAUDE.md` または `./.claude/CLAUDE.md`（プロジェクト）を確認
- 報告: 存在する？ サイズは？ 最終更新日は？ 内容の要約

### Skills（`~/.claude/skills/` と `./.claude/skills/`）
- 定義済みスキルを一覧
- 各スキル: 名前、説明、ユーザー呼び出し可能か

### Custom Agents（`~/.claude/agents/` と `./.claude/agents/`）
- 定義済みエージェントを一覧
- 各エージェント: 名前、説明、モデル、ツール

### Rules（`~/.claude/rules/` と `./.claude/rules/`）
- ルールファイルを一覧
- `paths:` frontmatter 付きのもの（条件付きルール）を注記

### MCP Servers
- `~/.claude.json` でグローバル MCP サーバーを確認
- `./.mcp.json` でプロジェクト MCP サーバーを確認
- 設定済みサーバーとトランスポートタイプを一覧

### Hooks
- settings.json 内の hooks 設定を確認
- Hook イベントとその内容を一覧

### Auto Memory
- 現在のプロジェクトの `~/.claude/projects/*/memory/MEMORY.md` を確認
- 報告: 存在する？ メモリファイル数は？ 最終更新日は？

### Keybindings
- `~/.claude/keybindings.json` を確認
- カスタマイズされているか報告

結果は簡潔なテーブルまたはチェックリストで提示すること。正常な項目にはチェックマーク、問題のある項目には警告を付ける。

## 3. 改善提案（`suggest` または `all`）

監査結果に基づき、具体的な改善を提案する。影響度で優先順位をつける:

**影響度・高:**
- コードのあるプロジェクトに CLAUDE.md がない
- 頻繁に承認しているツールを `permissions.allow` に入れるべき
- 自動フォーマット等の Hook があると便利な場面

**影響度・中:**
- 繰り返しのワークフローを Skill 化できる
- 並列作業を Agent で効率化できる
- 明らかに使っているサービスの MCP サーバー（GitHub, Jira 等）

**影響度・低:**
- キーバインドの最適化
- ルールファイルの整理
- メモリのクリーンアップ

### 却下済み提案の処理

**提案する前に必ず** `~/.claude/.setup-declined.json` が存在するか確認し、あれば読むこと。
このファイルはユーザーが過去に断った提案を記録している:

```json
{
  "declined": [
    {
      "id": "hook-autoformat",
      "description": "PostToolUse の自動フォーマット Hook",
      "declined_at": "2026-03-15",
      "declined_at_version": "2.1.76"
    }
  ]
}
```

ルール:
- `id` が一致する提案は**スキップ**する。**ただし** `claude --version` が `declined_at_version` より新しい場合は再提案する（新バージョンで機能が変わった可能性があるため）
- ユーザーが提案を断ったら、現在の日付と Claude Code バージョンと共にこのファイルに追記する
- ファイルが存在しなければ、最初の却下時に作成する
- ID は短く安定したものを使う（例: `hook-autoformat`, `mcp-github`, `skill-deploy`, `agent-reviewer`）

### 提案の書式

各提案について:
1. 何をするか（1文）
2. なぜ必要か（1文）
3. 「設定しますか？」と確認する

## 4. 変更の適用（`update`）

ユーザーが提案を承認した場合:
1. 変更内容の差分プレビューを表示する
2. ユーザーに最終確認する
3. 変更を適用する
4. 動作確認する（例: settings ファイルの JSON 構文チェック）
5. 却下リストに入っていた場合は削除する

**ユーザーの明示的な承認なしに変更を適用してはいけない。**

## 5. タイムスタンプの更新

**どのセクションを実行した場合でも**、最後に必ず以下を実行すること:
```bash
date +%s > ~/.claude/.last-setup-check
```
これにより7日リマインダーのタイマーがリセットされ、SessionStart Hook が不必要に通知しなくなる。

## 出力フォーマット

最初に1行サマリーを出す:
```
Claude Code v{version} | Settings: {status} | Skills: {count} | Agents: {count} | MCP: {count}
```

続けて該当セクションの詳細を表示する。
最後に優先度の高い提案を最大3つ表示する（特定セクションのみの実行時は省略可）。
