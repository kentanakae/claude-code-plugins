---
name: clasp-gemini
description: "Gemini CLIで別AIの視点を得る。コードレビューやタスク実行をGeminiに依頼する際に使用。multi-agent collaboration。"
allowed-tools: Bash(gemini:*), Bash(which:*)
argument-hint: [review|exec] [prompt]
context: fork
---

# Gemini CLI スキル

Gemini CLI を使って、別のAIエージェントの視点を得る。

## 前提条件

- Gemini CLI がインストールされている必要がある
- Google AI の認証が設定されている必要がある

## 手順

### Step 1: コマンドの存在確認

`gemini` コマンドが利用可能か確認する。

```bash
which gemini
```

コマンドが見つからない場合は、ユーザーにインストールを促して終了する。

> Gemini CLI がインストールされていません。以下を参考にインストールしてください:
> <https://github.com/google-gemini/gemini-cli>

### Step 2: 引数を確認

$ARGUMENTS を解析して実行モードを決定:

| 引数パターン | モード |
| ------------- | -------- |
| `review <prompt>` | 読み取り専用でレビュー |
| `exec <prompt>` | タスク実行 |
| 引数なし | ユーザーに確認 |

### Step 3: コマンド実行

#### review モード（読み取り専用）

```bash
gemini -s -p "<prompt>"
```

`-s` (sandbox) でサンドボックスモードを有効にし、安全にレビューする。

#### exec モード（タスク実行）

```bash
gemini -p "<prompt>"
```

自動承認が必要な場合:

```bash
gemini -y -p "<prompt>"
```

### Step 4: 結果を報告

実行結果をユーザーに報告する。

## 主なオプション

| オプション | 説明 |
| ----------- | ------ |
| `-m, --model <MODEL>` | 使用するモデルを指定 |
| `-p, --prompt <PROMPT>` | 非インタラクティブにプロンプトを実行 |
| `-s, --sandbox` | サンドボックスモードで実行 |
| `-y, --yolo` | 全てのアクションを自動承認 |

## 使用例

```bash
# レビューを依頼
gemini -s -p "このコードをレビューして"

# タスクを実行
gemini -p "このコードのパフォーマンスを改善して"

# 自動承認モードで実行
gemini -y -p "テストを追加して"
```
