# ファイル

## GET /rooms/{room_id}/files

チャットのファイル一覧を取得する（最大100件）。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.files:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |

**レスポンス (200)**: ファイルオブジェクトの配列

| フィールド | 型 | 説明 |
|-----------|------|------|
| file_id | integer | ファイルID |
| account.account_id | integer | アップロード者のアカウントID |
| account.name | string | アップロード者の表示名 |
| account.avatar_image_url | string | アップロード者のアバターURL |
| filename | string | ファイル名 |
| filesize | integer | ファイルサイズ（バイト） |
| upload_time | integer | アップロード時刻（Unixタイムスタンプ） |

```json
[
  {
    "file_id": 123,
    "account": {
      "account_id": 456,
      "name": "John Smith",
      "avatar_image_url": "https://example.com/avatar.png"
    },
    "filename": "document.pdf",
    "filesize": 102400,
    "upload_time": 1384242850
  }
]
```

---

## POST /rooms/{room_id}/files

チャットにファイルをアップロードする。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:write`

**Content-Type**: `multipart/form-data`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| file | file | はい | アップロードするファイル |
| message | string | いいえ | ファイルに付けるメッセージ |

**レスポンス (200)**:

```json
{
  "file_id": 1234
}
```

---

## GET /rooms/{room_id}/files/{file_id}

チャットのファイル情報を取得する。

**認証スコープ**: `rooms.all:read_write`, `rooms.all:read`, `rooms.files:read`

**パラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| room_id | integer | はい | ルームID（パスパラメータ） |
| file_id | integer | はい | ファイルID（パスパラメータ） |

**レスポンス (200)**:

| フィールド | 型 | 説明 |
|-----------|------|------|
| file_id | integer | ファイルID |
| name | string | ファイル名 |
| size | integer | ファイルサイズ（バイト） |
| create_time | integer | 作成時刻（Unixタイムスタンプ） |
| created_by_account.account_id | integer | アップロード者のアカウントID |
| created_by_account.name | string | アップロード者の表示名 |
| created_by_account.avatar_image_url | string | アップロード者のアバターURL |

```json
{
  "file_id": 123,
  "name": "document.pdf",
  "size": 2048,
  "create_time": 1384242850,
  "created_by_account": {
    "account_id": 456,
    "name": "John Smith",
    "avatar_image_url": "https://example.com/avatar.png"
  }
}
```
