# タスク

## GET /rooms/{room_id}/tasks

チャットのタスク一覧を取得する（最大100件）。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.tasks:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**: タスクオブジェクトの配列

| フィールド | 型 | 説明 |
|-----------|------|------|
| task_id | integer | タスクID |
| room.room_id | integer | ルームID |
| room.name | string | チャット名 |
| room.icon_path | string | チャットアイコンURL |
| assigned_by_account.account_id | integer | 依頼者のアカウントID |
| assigned_by_account.name | string | 依頼者の表示名 |
| assigned_by_account.avatar_image_url | string | 依頼者のアバターURL |
| message_id | string | 関連メッセージID |
| body | string | タスク内容（最大65,535文字） |
| limit_time | integer | 期限（Unixタイムスタンプ） |
| status | string | `open` または `done` |
| limit_type | string | `none`, `date`, `time` |

```json
[
  {
    "task_id": 3,
    "room": {
      "room_id": 5,
      "name": "Group Chat Name",
      "icon_path": "https://example.com/ico_group.png"
    },
    "assigned_by_account": {
      "account_id": 456,
      "name": "Anna",
      "avatar_image_url": "https://example.com/def.png"
    },
    "message_id": "13",
    "body": "buy milk",
    "limit_time": 1384354799,
    "status": "open",
    "limit_type": "date"
  }
]
```

---

## POST /rooms/{room_id}/tasks

チャットに新しいタスクを追加する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.tasks:write`

**レートリミット**: ルーム毎に10秒あたり10リクエスト

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| body | string | はい | タスク内容（1-65,535文字） |
| to_ids | string | いいえ | 担当者のアカウントIDのカンマ区切り |
| limit | integer | いいえ | 期限（Unixタイムスタンプ） |
| limit_type | string | いいえ | `none`, `date`, `time` |

**レスポンス (200)**: タスクオブジェクト（GET /rooms/{room_id}/tasks と同じ構造）

---

## GET /rooms/{room_id}/tasks/{task_id}

チャットのタスク情報を取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.tasks:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| task_id | integer | はい | タスクID（パスパラメータ） |

**レスポンス (200)**: タスクオブジェクト（GET /rooms/{room_id}/tasks と同じ構造）

---

## PUT /rooms/{room_id}/tasks/{task_id}/status

チャットのタスクの完了状態を変更する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.tasks:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| task_id | integer | はい | タスクID（パスパラメータ） |
| body | string | はい | `open` または `done` |

**レスポンス (200)**:

```json
{
  "task_id": 1234
}
```
