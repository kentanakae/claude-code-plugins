# 招待リンク

## GET /rooms/{room_id}/link

チャットへの招待リンクを取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.info:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**:

| フィールド | 型 | 説明 |
|-----------|------|------|
| public | boolean | 公開リンクかどうか |
| url | string | 招待リンクURL |
| need_acceptance | boolean | 参加に管理者承認が必要か |
| description | string | リンクの説明 |

```json
{
  "public": true,
  "url": "https://chatwork.com/r/xxxxx",
  "need_acceptance": false,
  "description": "join our chat"
}
```

---

## POST /rooms/{room_id}/link

チャットへの招待リンクを作成する。既にリンクが存在する場合は400エラー。

**認証スコープ**: `rooms.all:read_write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**:

| フィールド | 型 | 説明 |
|-----------|------|------|
| public | boolean | 公開リンクかどうか |
| url | string | 招待リンクURL |
| need_acceptance | boolean | 参加に管理者承認が必要か |
| description | string | リンクの説明 |
| code | string | リンクコード |

```json
{
  "public": true,
  "url": "https://chatwork.com/r/xxxxx",
  "need_acceptance": false,
  "description": "join our chat",
  "code": "xxxxx"
}
```

---

## PUT /rooms/{room_id}/link

チャットへの招待リンクを変更する。招待リンクが無効の場合は400エラー。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**:

```json
{
  "public": true,
  "url": "https://chatwork.com/r/xxxxx",
  "need_acceptance": false,
  "description": "join our chat"
}
```

---

## DELETE /rooms/{room_id}/link

チャットへの招待リンクを削除する。招待リンクが無効の場合は400エラー。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.info:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス**: 204 No Content
