# setup-xcodebuildmcp: スキル定義 自己更新フロー

> このファイルは `SKILL.md` の Step 0-2 で「スキル定義を更新する」が選ばれた時にのみ読み込まれるリファレンス。通常の install / edit / uninstall フローでは参照されない。

## 前提

- 編集対象は本スキルの `SKILL.md` 自身（`<このファイルの親ディレクトリ>/SKILL.md`）
- 読み込み元は SKILL.md の Step 0-2 の分岐から `Read` ツールでこのファイルを開いた時点
- 失敗時はフローを止めず、SKILL.md の Step 1 へフォールバックする

## Step A: ファイルパスの解決と書き込み権限確認

1. このリファレンスファイルが置かれているスキルディレクトリを特定する。例:

   ```bash
   # 自己更新が呼ばれた時点でのスキルディレクトリ
   skill_dir="$(dirname "$(dirname "<このリファレンスファイルの絶対パス>")")"
   # SKILL.md の絶対パス
   skill_md="$skill_dir/SKILL.md"
   ```

2. `[ -w "$skill_md" ]` で書き込み可能かチェック。プラグインが読み取り専用領域に配置されている場合は書き込めないので、その旨を表示してフォールバック。

## Step B: 公式ドキュメントの取得

WebFetch で以下を取得し、最新仕様を抽出する:

- `https://xcodebuildmcp.com/docs/configuration` — schemaVersion / トップレベルオプション / sessionDefaults フィールド一覧
- `https://xcodebuildmcp.com/docs/workflows` — `enabledWorkflows` の有効値一覧
- `https://raw.githubusercontent.com/cameroncooke/XcodeBuildMCP/main/config.example.yaml` — 公式の最新サンプル

WebFetch のいずれかが失敗した場合は、取得できた範囲で進めるか、全滅なら「ドキュメント取得に失敗しました。手動更新をご検討ください。」と表示してフォールバック。

## Step C: 差分の要約とユーザー確認

抽出した最新仕様と現在の SKILL.md の差分を以下の観点で要約してユーザーに提示する:

- 追加された `enabledWorkflows` 候補
- 削除された `enabledWorkflows` 候補（後方非互換の可能性に注意）
- 追加された `sessionDefaults` フィールド
- 削除された `sessionDefaults` フィールド
- 追加されたトップレベルオプション
- Step 4-2 テンプレートのデフォルト値変更（例: `iPhone 17` → 新モデル名）

AskUserQuestion で最終確認:

```
question: "上記の変更を SKILL.md に反映しますか？"
options:
  - label: "反映する (Recommended)"
    description: "Edit ツールで該当箇所を更新する"
  - label: "中止"
    description: "更新せず、今回はスキップとして Step 1 へ進む"
```

## Step D: SKILL.md の更新

「反映する」が選ばれたら、Edit ツールで以下を更新する（変更必要な箇所のみ）:

1. 冒頭引用ブロックのバージョン文字列 `**v<旧>**` → `**v<新>**`
2. Step 3 質問2 の参考リスト（v<旧> 時点 → v<新> 時点 とラベル更新、項目の追加/削除を反映）
3. Step 4-2 テンプレートの `# 利用可能: ...` コメント行のワークフロー列挙
4. Step 4-2 テンプレートの sessionDefaults / トップレベルオプションのコメント例（追加項目があれば追記、廃止項目があれば削除）
5. Step 4-2 テンプレートのデフォルト値（公式 example の最新シミュレータ名等）
6. 「対応 XcodeBuildMCP バージョン:」行の `(XcodeBuildMCP v<旧> schemaVersion: 1 準拠)` 等の派生記述

更新後、変更内容を簡潔に要約表示してから SKILL.md の Step 1 へ進む（フローを継続）。

## 注意事項

- 自己更新は本 SKILL.md 自身を書き換えるため、**実行直後に Claude Code セッションへ反映されない場合がある**。その場合は次回起動時から新仕様が有効になる旨をユーザーに案内する
- 今回のフロー（install / edit）は **更新前の現在の定義のまま続行する**（途中で定義が変わると整合性が崩れるため）
- 後方非互換変更（フィールド廃止など）が含まれる場合は、ユーザー確認時にハイライトする
