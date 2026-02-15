# コンタクト

## GET /contacts

コンタクト一覧を取得する。

**認証スコープ**: `contacts.all:read_write`, `contacts.all:read`

**パラメータ**: なし

**レスポンス (200)**: コンタクトオブジェクトの配列

| フィールド | 型 | 説明 |
|-----------|------|------|
| account_id | integer | アカウントID |
| room_id | integer | ダイレクトチャットのルームID |
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
    "room_id": 322,
    "name": "John Smith",
    "chatwork_id": "tarochatworkid",
    "organization_id": 101,
    "organization_name": "Hello Company",
    "department": "Marketing",
    "avatar_image_url": "https://example.com/abc.png"
  }
]
```
