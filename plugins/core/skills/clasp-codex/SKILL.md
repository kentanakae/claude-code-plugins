---
name: clasp-codex
description: "Codex CLIで別AIの視点を得る。コードレビューやタスク実行をCodexに依頼する際に使用。multi-agent collaboration。"
allowed-tools: Bash(codex:*), Bash(which:*)
argument-hint: [review|exec] [prompt]
context: fork
---

# Codex CLI スキル

Codex CLI を使って、別のAIエージェントの視点を得る。

## 前提条件

- Codex CLI がインストールされている必要がある
- OpenAI の API キーが設定されている必要がある

## 手順

### Step 1: コマンドの存在確認

`codex` コマンドが利用可能か確認する。

```bash
which codex
```

コマンドが見つからない場合は、ユーザーにインストールを促して終了する。

> Codex CLI がインストールされていません。以下を参考にインストールしてください:
> <https://github.com/openai/codex>

### Step 2: 引数を確認

$ARGUMENTS を解析して実行モードを決定:

| 引数パターン | モード |
| ------------- | -------- |
| `review` | コードレビュー（プロンプト不要） |
| `exec <prompt>` | タスク実行（プロンプト必須） |
| 引数なし | ユーザーに確認 |

### Step 3: コマンド実行

#### review モード（コードレビュー）

```bash
codex review
```

現在のリポジトリのコードレビューを実行する。プロンプト不要。

#### exec モード（タスク実行）

```bash
codex exec -s read-only "<prompt>"
```

読み取り専用モードで安全にタスクを実行する。

書き込みが必要な場合:

```bash
codex exec "<prompt>"
```

### Step 4: 結果を報告

実行結果をユーザーに報告する。

## 主なオプション

| オプション | 説明 |
| ----------- | ------ |
| `-m, --model <MODEL>` | 使用するモデル |
| `-s, --sandbox <MODE>` | サンドボックスポリシー（read-only, workspace-write, danger-full-access） |
| `-C, --cd <DIR>` | 作業ディレクトリを指定 |
| `--full-auto` | 低フリクションで自動実行 |

## 使用例

```bash
# レビューを依頼
codex review

# 読み取り専用で分析
codex exec -s read-only "このコードベースの構造を分析して"

# タスクを実行
codex exec "このコードのパフォーマンスを改善して"
```
