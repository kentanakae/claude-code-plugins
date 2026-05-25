---
name: clasp-antigravity
description: Antigravity CLI (agy) で別AIの視点を得る。Gemini CLIの後継。コードレビューやタスク実行をAntigravityに依頼する際に使用。multi-agent collaboration。
allowed-tools: Bash(agy:*), Bash(which:*)
argument-hint: [review|exec] [prompt]
context: fork
---

# Antigravity CLI スキル

Antigravity CLI（バイナリ名 `agy`）を使って、別のAIエージェントの視点を得る。Google が 2026-05-19 に公開した Gemini CLI の後継。

> **背景**: Gemini CLI は 2026-06-18 に Free/Pro/Ultra ユーザー向けで停止された（Standard/Enterprise ライセンスは継続）。本スキルはその後継として運用する。

## 前提条件

- Antigravity CLI（`agy`）がインストールされている必要がある
- Google アカウントでサインイン済みである必要がある（初回起動時に OAuth フロー）

未インストール時のインストール手順（参考）:

```bash
# macOS / Linux
curl -fsSL https://antigravity.google/cli/install.sh | bash

# Windows (PowerShell)
irm https://antigravity.google/cli/install.ps1 | iex
```

旧 Gemini CLI のプラグイン設定を引き継ぐ場合:

```bash
agy plugin import gemini
```

## 手順

### Step 1: コマンドの存在確認

`agy` コマンドが利用可能か確認する。

```bash
which agy
```

`agy` が見つからない場合は、上記インストール手順を案内した上で、緊急時は Claude `opus` モデルのサブエージェント（Task ツールで `model: "opus"`）への切替も選択肢として提示して終了する。

### Step 2: 引数を確認

`$ARGUMENTS` を解析して実行モードを決定:

| 引数パターン | モード |
| ------------- | -------- |
| `review <prompt>` | 読み取り専用でレビュー |
| `exec <prompt>` | タスク実行 |
| 引数なし | ユーザーに確認 |

### Step 3: コマンド実行

#### review モード（読み取り専用）

`--sandbox` でサンドボックス起動し、副作用のないレビューを行う。さらにプロンプト側でも読み取り専用を明示するとより堅い。

```bash
agy --sandbox -p "[READ-ONLY REVIEW] Do not modify, create, or delete any files. Only analyze and report findings. Task: <prompt>"
```

#### exec モード（タスク実行）

```bash
agy -p "<prompt>"
```

全アクションを自動承認したい場合（Gemini CLI の `-y` 相当）:

```bash
agy --dangerously-skip-permissions -p "<prompt>"
```

> v1.0.2 時点ではモデル選択フラグ（`-m` 相当）と構造化出力フラグ（`--output-format json` 相当）は提供されていない。モデルは固定、出力は標準出力プレーンテキスト。

### Step 4: 結果を報告

実行結果をユーザーに報告する。

## 主なオプション（v1.0.2 実機検証済み）

| オプション | 説明 |
| ----------- | ------ |
| `-p, --print` | 非対話モードでプロンプトを実行（`--prompt` も同義のエイリアス） |
| `--sandbox` | サンドボックスモードで起動（Gemini CLI の `-s` 相当、副作用なしのレビュー向け） |
| `--dangerously-skip-permissions` | 権限確認をスキップし全アクションを自動承認（Gemini CLI の `-y` / yolo 相当） |
| `--add-dir <DIR>` | ワークスペースにディレクトリを追加（複数指定可） |
| `-c, --continue` | 直近の会話を継続 |
| `--conversation <ID>` | 指定 ID の会話を再開 |
| `-i, --prompt-interactive <PROMPT>` | 初期プロンプトを渡して対話セッション継続 |
| `--print-timeout <DUR>` | print モードのタイムアウト（デフォルト 5m0s） |
| `agy plugin import gemini` | 旧 Gemini CLI のプラグインを移行（`import claude` で Claude Code 設定も可） |
| `agy plugin list` / `install` / `uninstall` / `enable` / `disable` | プラグイン管理 |
| `agy update` | CLI 更新 |
| `agy changelog` | リリースノート表示 |
| `agy --version` | バージョン確認 |

> 一次情報は `agy --help` の実出力。仕様変更があれば本スキルを更新すること。モデル選択（`-m` 相当）や構造化出力（`--output-format json` 相当）は v1.0.2 では未提供。

## 使用例

```bash
# レビューを依頼（読み取り専用、サンドボックス）
agy --sandbox -p "[READ-ONLY REVIEW] Do not modify files. Review this codebase for security issues."

# タスクを実行
agy -p "このコードのパフォーマンスを改善して"

# 全自動承認モード
agy --dangerously-skip-permissions -p "テストを追加して"

# 直近の会話を継続
agy -c -p "前回の続きで、エッジケースのテストも追加して"

# 特定ディレクトリをワークスペースに追加
agy --add-dir /path/to/other-repo -p "両リポを横断してインターフェース差分を確認"
```

## フォールバック

`agy` が利用できない場合は、Claude `opus` モデルのサブエージェント（Task ツールで `model: "opus"`）に調査・分析を依頼する。
