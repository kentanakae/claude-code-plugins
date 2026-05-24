---
name: clasp-gemini
description: 【非推奨: 2026-06-18でGemini CLI停止】Gemini CLIで別AIの視点を得る。後継は/clasp-antigravity。併存期間中のフォールバックとしてのみ利用。
allowed-tools: Bash(gemini:*), Bash(which:*), Skill(clasp-antigravity *)
argument-hint: [review|exec] [prompt]
context: fork
---

# Gemini CLI スキル（非推奨）

> **⚠ 非推奨（DEPRECATED）**: Google は Gemini CLI を Antigravity CLI（`agy`）へ移行する方針を発表した。
>
> - **2026-05-19**: Antigravity CLI 一般公開
> - **2026-06-18**: Gemini CLI / Gemini Code Assist IDE 拡張が Free / Pro / Ultra ユーザー向けでリクエスト受付を停止（Standard / Enterprise ライセンスは継続）
>
> **新規利用は `/clasp-antigravity` スキルを使用すること。** 本スキルは併存期間中（〜2026-06-18）に `agy` 未インストール環境で `gemini` のみ利用可能な場合のフォールバックとして残置する。

Gemini CLI を使って、別のAIエージェントの視点を得る。

## 前提条件

- Gemini CLI がインストールされている必要がある
- Google AI の認証が設定されている必要がある
- **本スキルを呼ぶ前に `/clasp-antigravity` が利用可能かを優先して確認すること**

## 手順

### Step 0: 後継スキル自動委譲

`agy`（Antigravity CLI）が利用可能なら、本スキルでは作業せず、**Skill ツールで `clasp-antigravity` を呼び出して作業を委譲する**。委譲後は本スキルの Step 1 以降には進まず、委譲先の結果をそのままユーザーへの応答として返す。

```bash
which agy
```

`agy` が見つかる場合の処理:

1. ユーザーに「Antigravity CLI を検出したため `/clasp-antigravity` に切り替えて実行します」と一言伝える
2. **Skill** ツールを呼び出す:
   - `skill` パラメータ: `clasp-antigravity`
   - `args` パラメータ: 本スキル起動時に `$ARGUMENTS` として受け取った引数文字列を **一切加工せず・要約せず・モード判定の解釈も入れずに、そのまま実値として** 渡す（例: ユーザーが `/clasp-gemini review このコード` で呼んだなら `args: "review このコード"`）。引数の解釈（review / exec モード判定など）は委譲先の `clasp-antigravity` Step 2 で行われるため、本スキル側で先回りして加工しない
3. 委譲先の応答をユーザーに伝えて本スキルは終了する

**Skill ツールでの委譲に失敗した場合のフォールバック**: Skill ツールが利用不可・呼び出しエラー等の場合は、ユーザーに「`/clasp-antigravity` を直接実行してください」と案内した上で、Step 1 以降のレガシー `gemini` 呼び出しに進むかをユーザーに確認する。

`agy` が見つからない場合のみ、Step 1 以降のレガシー `gemini` 呼び出しに進む。

### Step 1: コマンドの存在確認

`gemini` コマンドが利用可能か確認する。

```bash
which gemini
```

コマンドが見つからない場合は、ユーザーに後継 CLI のインストールを促して終了する。

> Gemini CLI も Antigravity CLI も見つかりません。後継の Antigravity CLI のインストールを推奨します:
> `curl -fsSL https://antigravity.google/cli/install.sh | bash`

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

実行結果をユーザーに報告する。報告末尾に「Gemini CLI は 2026-06-18 で停止予定。次回からは `/clasp-antigravity` の利用を推奨」を一言添える。

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

## 移行ガイド

| Gemini CLI | Antigravity CLI（v1.0.2 で検証済み） |
| ----------- | -------------------- |
| `gemini -p "..."` | `agy -p "..."` |
| `gemini -y -p "..."` | `agy --dangerously-skip-permissions -p "..."` |
| `gemini -s -p "..."` | `agy --sandbox -p "..."` |
| `gemini -m <model> -p "..."` | v1.0.2 ではモデル選択フラグ未提供（モデル固定運用） |
| プラグイン設定 | `agy plugin import gemini` で移行 |
