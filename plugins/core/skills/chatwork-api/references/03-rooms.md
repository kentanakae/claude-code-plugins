# チャットルーム

## GET /rooms

自分のチャット一覧を取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.info:read`

**パラメータ**: なし

**レスポンス (200)**: ルームオブジェクトの配列

| フィールド | 型 | 説明 |
|-----------|------|------|
| room_id | integer | ルームID |
| name | string | チャット名 |
| type | string | `my`, `direct`, `group` |
| role | string | `admin`, `member`, `readonly` |
| sticky | boolean | ピン留めされているか |
| unread_num | integer | 未読メッセージ数 |
| mention_num | integer | 未読メンション数 |
| mytask_num | integer | 自分のタスク数 |
| message_num | integer | メッセージ総数 |
| file_num | integer | ファイル総数 |
| task_num | integer | タスク総数 |
| icon_path | string | チャットアイコンURL |
| last_update_time | integer | 最終更新時刻（Unixタイムスタンプ） |

```json
[
  {
    "room_id": 123,
    "name": "Group Chat Name",
    "type": "group",
    "role": "admin",
    "sticky": false,
    "unread_num": 10,
    "mention_num": 1,
    "mytask_num": 0,
    "message_num": 122,
    "file_num": 10,
    "task_num": 17,
    "icon_path": "https://example.com/ico_group.png",
    "last_update_time": 1298905200
  }
]
```

---

## POST /rooms

グループチャットを新規作成する。作成者は自動的に管理者になる。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| name | string | はい | チャット名（1-255文字） |
| description | string | いいえ | チャットの概要説明 |
| link | integer | いいえ | 招待リンクを作成するか（0 or 1） |
| link_code | string | いいえ | 招待リンクのパス（1-50文字、英数字+`_-`） |
| link_need_acceptance | integer | いいえ | 参加に管理者承認が必要か（デフォルト: 1） |
| members_admin_ids | string | はい | 管理者にするアカウントIDのカンマ区切り（最低1名） |
| members_member_ids | string | いいえ | メンバーにするアカウントIDのカンマ区切り |
| members_readonly_ids | string | いいえ | 閲覧のみにするアカウントIDのカンマ区切り |
| icon_preset | string | いいえ | アイコン種別: `group`, `check`, `document`, `meeting`, `event`, `project`, `business`, `study`, `security`, `star`, `idea`, `heart`, `magcup`, `beer`, `music`, `sports`, `travel` |

**レスポンス (200)**:

```json
{
  "room_id": 1234
}
```

---

## GET /rooms/{room_id}

チャットの情報（名前、アイコン、種類など）を取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.info:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**:

GET /rooms のレスポンスフィールドに加え:

| フィールド | 型 | 説明 |
|-----------|------|------|
| description | string | チャットの概要説明 |

```json
{
  "room_id": 123,
  "name": "Group Chat Name",
  "type": "group",
  "role": "admin",
  "sticky": false,
  "unread_num": 10,
  "mention_num": 1,
  "mytask_num": 0,
  "message_num": 122,
  "file_num": 10,
  "task_num": 17,
  "icon_path": "https://example.com/ico_group.png",
  "last_update_time": 1298905200,
  "description": "room description text"
}
```

---

## PUT /rooms/{room_id}

チャットの情報を更新する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.info:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| name | string | いいえ | チャット名（1-255文字） |
| description | string | いいえ | チャットの概要説明 |
| icon_preset | string | いいえ | アイコン種別（POST /rooms と同じ選択肢） |

**レスポンス (200)**:

```json
{
  "room_id": 1234
}
```

---

## DELETE /rooms/{room_id}

グループチャットを退席、または削除する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| action_type | string | はい | `leave`（退席）または `delete`（削除） |

**レスポンス**: 204 No Content

**注意事項**:

- 退席すると、自分が担当のタスクと自分が送信したファイルがすべて削除される
- 削除は取り消し不可
- ダイレクトチャット・マイチャットは退席/削除不可
