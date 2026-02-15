# メッセージ

## GET /rooms/{room_id}/messages

チャットのメッセージ一覧を取得する（最大100件）。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.messages:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| force | integer | いいえ | 1: 最新100件を強制取得、0: 前回以降の差分のみ（デフォルト: 0） |

**レスポンスヘッダー（追加）**:

- `chatwork-message-limitation`: メッセージ閲覧制限の有無
- `chatwork-message-limitation-summary`: 制限の理由

**レスポンス (200)**: メッセージオブジェクトの配列

| フィールド | 型 | 説明 |
|-----------|------|------|
| message_id | string | メッセージID |
| account.account_id | integer | 送信者のアカウントID |
| account.name | string | 送信者の表示名 |
| account.avatar_image_url | string | 送信者のアバターURL |
| body | string | メッセージ本文 |
| send_time | integer | 送信時刻（Unixタイムスタンプ） |
| update_time | integer | 更新時刻（Unixタイムスタンプ） |

```json
[
  {
    "message_id": "5",
    "account": {
      "account_id": 123,
      "name": "Bob",
      "avatar_image_url": "https://example.com/ico_avatar.png"
    },
    "body": "Hello Chatwork!",
    "send_time": 1384242850,
    "update_time": 0
  }
]
```

---

## POST /rooms/{room_id}/messages

チャットに新しいメッセージを投稿する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.messages:write`

**レートリミット**: ルーム毎に10秒あたり10リクエスト

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| body | string | はい | メッセージ本文（1-65,535文字） |
| self_unread | integer | いいえ | 0: 既読（デフォルト）、1: 自分の未読にする |

**レスポンス (200)**:

```json
{
  "message_id": "1234"
}
```

---

## GET /rooms/{room_id}/messages/{message_id}

メッセージを個別に取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.messages:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| message_id | string | はい | メッセージID（パスパラメータ） |

**レスポンス (200)**:

```json
{
  "message_id": "5",
  "account": {
    "account_id": 123,
    "name": "Bob",
    "avatar_image_url": "https://example.com/ico_avatar.png"
  },
  "body": "Hello Chatwork!",
  "send_time": 1384242850,
  "update_time": 0
}
```

---

## PUT /rooms/{room_id}/messages/{message_id}

チャットのメッセージを更新する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.messages:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| message_id | string | はい | メッセージID（パスパラメータ） |
| body | string | はい | メッセージ本文（1-65,535文字） |

**レスポンス (200)**:

```json
{
  "message_id": "1234"
}
```

---

## DELETE /rooms/{room_id}/messages/{message_id}

チャットのメッセージを削除する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.messages:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| message_id | string | はい | メッセージID（パスパラメータ） |

**レスポンス**: 204 No Content

**注意事項**:

- メッセージの投稿者またはルーム管理者のみ削除可能
- 削除は取り消し不可

---

## PUT /rooms/{room_id}/messages/read

チャットのメッセージを既読にする。指定したメッセージIDまでのメッセージが既読になる。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.messages:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| message_id | string | はい | このメッセージIDまでを既読にする |

**レスポンス (200)**:

| フィールド | 型 | 説明 |
|-----------|------|------|
| unread_num | integer | 未読メッセージ残数 |
| mention_num | integer | 未読メンション残数 |

```json
{
  "unread_num": 3,
  "mention_num": 0
}
```

---

## PUT /rooms/{room_id}/messages/unread

チャットのメッセージを未読にする。指定したメッセージID以降のメッセージが未読になる。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.messages:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| message_id | string | はい | このメッセージID以降を未読にする |

**レスポンス (200)**:

| フィールド | 型 | 説明 |
|-----------|------|------|
| unread_num | integer | 未読メッセージ数 |
| mention_num | integer | 未読メンション数 |

```json
{
  "unread_num": 3,
  "mention_num": 0
}
```
