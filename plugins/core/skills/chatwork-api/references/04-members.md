# メンバー

## GET /rooms/{room_id}/members

チャットのメンバー一覧を取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.members:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**: メンバーオブジェクトの配列

| フィールド | 型 | 説明 |
|-----------|------|------|
| account_id | integer | アカウントID |
| role | string | `admin`, `member`, `readonly` |
| name | string | 表示名 |
| chatwork_id | string | Chatwork ID |
| organization_id | integer | 組織ID |
| organization_name | string | 組織名 |
| department | string | 部署 |
| avatar_image_url | string | アバター画像URL |

```json
[
  {
    "account_id": 123,
    "role": "member",
    "name": "John Smith",
    "chatwork_id": "tarochatworkid",
    "organization_id": 101,
    "organization_name": "Hello Company",
    "department": "Marketing",
    "avatar_image_url": "https://example.com/abc.png"
  }
]
```

---

## PUT /rooms/{room_id}/members

チャットのメンバーを一括で変更する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`, `rooms.members:write`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| members_admin_ids | string | はい | 管理者にするアカウントIDのカンマ区切り（最低1名） |
| members_member_ids | string | いいえ | メンバーにするアカウントIDのカンマ区切り |
| members_readonly_ids | string | いいえ | 閲覧のみにするアカウントIDのカンマ区切り |

**レスポンス (200)**:

```json
{
  "admin": [123, 542, 1001],
  "member": [10, 103],
  "readonly": [6, 11]
}
```
