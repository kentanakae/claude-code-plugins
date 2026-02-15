---
name: chatwork-api
description: "Chatwork API リファレンス。チャットワークのrooms, messages, tasks, files, members, contacts, invitationsの認証・エンドポイント・パラメータ仕様を提供。"
user-invocable: false
---

# Chatwork REST API v2 リファレンス

Chatwork REST API v2 の全エンドポイントに関する知識を提供するリファレンススキル。

## 基本情報

- **Base URL**: `https://api.chatwork.com/v2`
- **プロトコル**: HTTPS 必須
- **レスポンス形式**: JSON
- **リクエストボディ**: `application/x-www-form-urlencoded`（POST/PUT）

## 認証

### API トークン

リクエストヘッダーに `X-ChatWorkToken` を設定する。

```
X-ChatWorkToken: YOUR_API_TOKEN
```

- トークンの取得: Chatwork画面 → ユーザー名クリック → サービス連携 → APIトークン
- トークンに有効期限はない
- クエリストリングではなく、必ずヘッダーで送信する

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
