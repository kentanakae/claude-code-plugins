---
name: chatwork-api
description: Chatwork API の呼び出し規約とリファレンス。MCP `mcp__chatwork__*` を第一経路、同梱ラッパー `scripts/api-request.sh` を第二経路、それ以外は停止という3段ルールを規定。rooms/messages/tasks/files/members/contacts/invitations のエンドポイント仕様、認証、エンコード規則を提供。
when_to_use: |
  Chatwork API に触れる前に必ず参照する。
  - Chatwork のメッセージ・タスク・ルーム・ファイル・メンバー・コンタクト・招待リンクを投稿/取得/更新/削除する
  - `mcp__chatwork__*` のいずれかを呼ぼうとしている
  - `api.chatwork.com` を curl 等で叩こうとしている
  - Chatwork のタグ（`[To:]`, `[rep aid=]`, `[info]`, `[picon:]` 等）を含む本文を組み立てる
  - `CHATWORK_API_TOKEN` を扱う／読もうとする
  SKIP:
  - Chatwork と無関係な HTTP 呼び出し
  - GitHub / Slack / Phrase 等、別サービスの API 作業
user-invocable: false
---

# Chatwork REST API v2 リファレンス

Chatwork REST API v2 の全エンドポイントに関する知識を提供するリファレンススキル。

## 基本情報

- **Base URL**: `https://api.chatwork.com/v2`
- **プロトコル**: HTTPS 必須
- **レスポンス形式**: JSON
- **リクエストボディ**: `application/x-www-form-urlencoded`（POST/PUT）

## 呼び出し経路（必読）

実行は以下の優先順位で固定する。**Bash で `curl`／`wget`／`httpie` を直接書かない**こと。トークンが transcript に露出し、タグ・URL・日本語のエンコード崩れも防げない。

### 1. 第一経路: MCP `mcp__chatwork__*`（原則これを使う）

メッセージ・タスク・ルーム・既読/未読・コンタクト・招待リンク・承認リクエストはすべて MCP ツールで対応可能。

- 引数は JSON 文字列で渡し、MCP server 内で URL エンコードされる → `[To:123]`、`[info]...[/info]`、日本語、絵文字、改行、URL（生／既エンコード問わず）すべて素のまま渡せる
- API トークンは MCP server プロセス内のみに存在し、Bash 入力に登場しない

主要ツール: `post_room_message` / `update_room_message` / `delete_room_message` / `list_room_messages` / `get_room_message` / `read_room_messages` / `unread_room_message` / `create_room_task` / `list_room_tasks` / `update_room_task_status` / `list_rooms` / `create_room` / `get_room` / `update_room` / `list_room_members` / `update_room_members` / `list_contacts` / `get_me` / `get_my_status` / `list_my_tasks` / `*_room_link` / `*_incoming_request` 等。

### 2. 第二経路: 同梱ラッパー `scripts/api-request.sh`（MCP に無いものだけ）

主用途は **ファイルアップロード** `POST /rooms/{id}/files`（MCP 未対応）。

```bash
~/.claude/skills/chatwork-api/scripts/api-request.sh GET /me
~/.claude/skills/chatwork-api/scripts/api-request.sh GET /rooms force=1
~/.claude/skills/chatwork-api/scripts/api-request.sh POST /rooms/123/files \
  -F "file=@./report.pdf" -F "message_ids=456"
```

仕様：

- トークンは `CHATWORK_API_TOKEN` 環境変数から取得し、`curl -K` の config 経由で渡すため argv に出ない
- `key=value` 形式の引数は自動的に `--data-urlencode` 経由で送られる → **literal 文字列をそのまま渡せばよい。自前で URL エンコードしないこと**（二重エンコードになる）
- `GET` は `-G` 自動付与で query string 化
- 長文 body は `body@/path/to/file.txt` でファイル投入可
- ファイルアップロードは `-F` を直接渡す（multipart はラッパーの自動エンコード対象外）

### 3. 禁止事項

- Bash で `curl`／`wget`／`httpie` を直接呼ばない
- `echo $CHATWORK_API_TOKEN` / `env` / `printenv` / `bash -x` / `set -x` 禁止
- MCP もラッパーも対応しない API は **作業を止めてユーザに相談**

## 事前条件と失敗時の対応

`CHATWORK_API_TOKEN` 環境変数が必須。未設定だと両経路とも失敗する：

- **MCP**: 空のトークンで API に到達 → 401 Unauthorized が返る
- **ラッパー**: `error: CHATWORK_API_TOKEN is not set.` で即終了（API には到達しない）

これらの症状を観測したら、**トークン値を表示せず**、ユーザに `export CHATWORK_API_TOKEN=...` を促すこと。

確認・対処の手順:

1. 存在のみ確認: `[ -n "${CHATWORK_API_TOKEN:-}" ] && echo set || echo unset`
   （`echo $CHATWORK_API_TOKEN` / `env | grep CHATWORK` / `printenv` は禁止）
2. 未設定ならユーザに伝えて設定を依頼。値の貼り付け先はチャットではなくシェル（`! export ...` か `~/.zshrc` 等の永続設定）
3. 設定済みなのに 401 が続く → トークンの誤り／失効の可能性。再取得をユーザに依頼

## 認証

### API トークン

リクエストヘッダーに `X-ChatWorkToken` を設定する。

```
X-ChatWorkToken: YOUR_API_TOKEN
```

- トークンの取得: Chatwork画面 → ユーザー名クリック → サービス連携 → APIトークン
- トークンに有効期限はない
- クエリストリングではなく、必ずヘッダーで送信する
- **実際の呼び出しではトークン値を直書きしない**。MCP もしくは `scripts/api-request.sh`（環境変数 `CHATWORK_API_TOKEN` 参照）を使う。

### OAuth 2.0

各エンドポイントに必要なスコープが定義されている。詳細は各エンドポイントのリファレンスを参照。

## レートリミット

| 制限種別 | 上限 | 期間 |
|---------|------|------|
| 全般 | 300リクエスト | 5分 |
| メッセージ投稿・タスク追加（ルーム毎） | 10リクエスト | 10秒 |

レスポンスヘッダーで確認可能:

- `x-ratelimit-limit`: 最大リクエスト数
- `x-ratelimit-remaining`: 残りリクエスト数
- `x-ratelimit-reset`: リセット時刻（Unixタイムスタンプ）

超過時は HTTP 429 が返却される。

## エラーレスポンス

エラー時は `errors` 配列を含むJSONが返却される。

```json
{
  "errors": ["エラーメッセージ"]
}
```

| ステータス | 説明 |
|-----------|------|
| 400 | リクエストパラメータ不正 |
| 401 | 認証失敗 |
| 403 | 権限不足 |
| 404 | リソース未検出 |
| 429 | レートリミット超過 |

## エンドポイント一覧

### ユーザー・アカウント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/me` | 自分自身の情報を取得 |
| GET | `/my/status` | 未読数・タスク数などのステータスを取得 |
| GET | `/my/tasks` | 自分のタスク一覧を取得（最大100件） |

### コンタクト

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/contacts` | コンタクト一覧を取得 |

### チャットルーム

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/rooms` | チャット一覧を取得 |
| POST | `/rooms` | グループチャットを作成 |
| GET | `/rooms/{room_id}` | チャット情報を取得 |
| PUT | `/rooms/{room_id}` | チャット情報を更新 |
| DELETE | `/rooms/{room_id}` | グループチャットを退席/削除 |

### メンバー

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/rooms/{room_id}/members` | メンバー一覧を取得 |
| PUT | `/rooms/{room_id}/members` | メンバーを一括変更 |

### メッセージ

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/rooms/{room_id}/messages` | メッセージ一覧を取得（最大100件） |
| POST | `/rooms/{room_id}/messages` | メッセージを投稿 |
| GET | `/rooms/{room_id}/messages/{message_id}` | メッセージを取得 |
| PUT | `/rooms/{room_id}/messages/{message_id}` | メッセージを更新 |
| DELETE | `/rooms/{room_id}/messages/{message_id}` | メッセージを削除 |
| PUT | `/rooms/{room_id}/messages/read` | メッセージを既読にする |
| PUT | `/rooms/{room_id}/messages/unread` | メッセージを未読にする |

### タスク

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/rooms/{room_id}/tasks` | タスク一覧を取得（最大100件） |
| POST | `/rooms/{room_id}/tasks` | タスクを追加 |
| GET | `/rooms/{room_id}/tasks/{task_id}` | タスク情報を取得 |
| PUT | `/rooms/{room_id}/tasks/{task_id}/status` | タスクの完了状態を変更 |

### ファイル

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/rooms/{room_id}/files` | ファイル一覧を取得（最大100件） |
| POST | `/rooms/{room_id}/files` | ファイルをアップロード |
| GET | `/rooms/{room_id}/files/{file_id}` | ファイル情報を取得 |

### 招待リンク

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/rooms/{room_id}/link` | 招待リンクを取得 |
| POST | `/rooms/{room_id}/link` | 招待リンクを作成 |
| PUT | `/rooms/{room_id}/link` | 招待リンクを変更 |
| DELETE | `/rooms/{room_id}/link` | 招待リンクを削除 |

### コンタクト承認リクエスト

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/incoming_requests` | 承認待ちリクエスト一覧を取得（最大100件） |
| PUT | `/incoming_requests/{request_id}` | リクエストを承認 |
| DELETE | `/incoming_requests/{request_id}` | リクエストを拒否 |

## 詳細リファレンス

各エンドポイントの詳細なパラメータ、レスポンスフィールド、使用例については以下を参照。

- [ユーザー・アカウント](references/01-me.md) - GET /me, GET /my/status, GET /my/tasks
- [コンタクト](references/02-contacts.md) - GET /contacts
- [チャットルーム](references/03-rooms.md) - GET/POST/GET(id)/PUT/DELETE /rooms
- [メンバー](references/04-members.md) - GET/PUT /rooms/{room_id}/members
- [メッセージ](references/05-messages.md) - GET/POST/GET(id)/PUT/DELETE + 既読/未読
- [タスク](references/06-tasks.md) - GET/POST/GET(id)/PUT(status)
- [ファイル](references/07-files.md) - GET/POST/GET(id)
- [招待リンク](references/08-invitation-link.md) - GET/POST/PUT/DELETE /rooms/{room_id}/link
- [コンタクト承認リクエスト](references/09-incoming-requests.md) - GET/PUT/DELETE /incoming_requests
