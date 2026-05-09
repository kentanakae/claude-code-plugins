---
name: setup-xcodebuildmcp
description: XcodeBuildMCP の設定ファイル（.xcodebuildmcp/config.yaml）をプロジェクトに生成・セットアップする。xcodebuildmcp, config, setup, simulator, build, Xcode
argument-hint: [install|edit|uninstall]
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, AskUserQuestion, ExitPlanMode
---

> 対応 XcodeBuildMCP バージョン: v2.5.1（schemaVersion: 1）。新しいバージョンが出た場合は `enabledWorkflows` の一覧と `sessionDefaults` のフィールドを公式ドキュメント（https://xcodebuildmcp.com/docs/configuration）と突き合わせて更新すること。

## Step 0: プランモード解除

プランモードが有効な場合は、ExitPlanMode ツールを呼び出して解除する。プランモードでない場合はスキップ。

## Step 1: 引数判定と前提確認

### 1-0. 引数ルーティング

- `$ARGUMENTS[0]` が `install` → Step 1-1 → Step 1-2 へ（既存設定があれば「上書き / キャンセル」の **2択のみ** を提示。「編集」は出さない）
- `$ARGUMENTS[0]` が `edit` → Step 1-1 を **スキップ** し直接 Step 5 へ（既存 config.yaml の編集に xcodebuildmcp 本体は不要）。config.yaml が存在しない場合は「設定がありません。`/setup-xcodebuildmcp install` を実行してください」と案内して終了
- `$ARGUMENTS[0]` が `uninstall` → Step 6 へ直行（前提確認不要）
- 引数なし or 上記以外 → Step 1-1 → Step 1-2 へ（既存設定の有無により自動分岐。既存ありなら「上書き / 編集 / キャンセル」の **3択**）

### 1-1. xcodebuildmcp の存在確認

以下の順序で確認する:

1. `which xcodebuildmcp` を実行
2. 見つからなければ `npx -y xcodebuildmcp@latest --version` を実行

どちらも失敗した場合、以下のインストール方法を案内して終了:

```
# Homebrew（推奨）
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp

# npm
npm install -g xcodebuildmcp@latest
```

### 1-2. 既存設定の確認

Glob で `.xcodebuildmcp/config.yaml` が既に存在するか確認する。

- 存在する場合 → Read で内容を表示し、AskUserQuestion で確認:
  - **`install` 引数の場合（2択）**: 「上書き (Recommended) / キャンセル」
    - 「上書き」→ Step 2 へ
    - 「キャンセル」→ 終了
  - **引数なしの場合（3択）**: 「編集 (Recommended) / 上書き / キャンセル」
    - 「編集」→ Step 5（編集フロー）へ
    - 「上書き」→ Step 2 へ
    - 「キャンセル」→ 終了
- 存在しない場合 → Step 2 へ

## Step 2: プロジェクト検出

### 2-1. Xcode プロジェクトファイルの検出

カレントディレクトリ直下で以下を Glob で検索する:

- `*.xcworkspace`
- `*.xcodeproj`

**除外ルール**: 以下はマッチしても無視する:
- `Pods.xcworkspace`（CocoaPods の内部ワークスペース）
- `.xcodeproj` 内部の `project.xcworkspace`（`*.xcodeproj/project.xcworkspace` パターン）

検出結果に基づいて処理を分岐:

- `.xcworkspace` のみ → `workspacePath` として使用
- `.xcodeproj` のみ → `projectPath` として使用
- 両方ある場合 → AskUserQuestion でどちらを使うか選択させる。`.xcworkspace` 側の label に `(Recommended)` を付与（CocoaPods / SwiftPM 統合プロジェクトでは workspace が必要なため）
- どちらもない場合 → AskUserQuestion でパスを手動入力させる

### 2-2. スキーム一覧の取得

検出したプロジェクトに対して `xcodebuild -list` を実行し、利用可能なスキーム一覧を取得する。

- `-workspace` または `-project` オプションを 2-1 の結果に基づいて付与
- 取得成功 → 以下の順序でソートし Step 3 で使用:
  1. プロジェクト名（`.xcodeproj` / `.xcworkspace` のベース名）と完全一致するスキームを最優先で先頭に
  2. プロジェクト名で前方一致するスキーム（例: `App-Dev`, `AppTests`）
  3. それ以外は `xcodebuild -list` の出力順を維持
- 取得失敗 → エラー出力（stderr）の要点を表示してから手動入力に切り替える

## Step 3: 対話的設定（基本）

1回目の AskUserQuestion で以下の2問を同時に確認する。

### 質問1: スキーム選択

- Step 2-2 でスキーム一覧が取得できた場合: ソート後の上位3つを選択肢として提示（先頭に `(Recommended)` を付与。4つ目は「Other」で手動入力可能）
- 取得できなかった場合: 手動入力を求める

### 質問2: ワークフロー選択（multiSelect: true）

主要ワークフローを4つ提示する（その他は Step 4 生成後に config.yaml を直接編集して追加可能）。`simulator` の label に `(Recommended)` を付与する:

| ワークフロー | 説明 |
|---|---|
| simulator (Recommended) | シミュレータでのビルド・実行 |
| device | 実機（iPhone / iPad / Apple Watch / Apple TV / Vision Pro） |
| ui-automation | UI 自動化・アクセシビリティテスト |
| debugging | LLDB デバッガ連携・ブレークポイント |

**参考: 利用可能な全ワークフロー（v2.5.1 時点、`enabledWorkflows` に追記可能）**

- `simulator` — シミュレータ向けビルド・実行
- `device` — 実機向けビルド・実行
- `macos` — macOS アプリのビルド・テスト
- `swift-package` — Swift Package Manager プロジェクト
- `ui-automation` — UI 自動化・アクセシビリティ
- `debugging` — LLDB デバッガ
- `coverage` — xcresult のコードカバレッジ
- `xcode-ide` — Xcode 26+ IDE 連携（mcpbridge）
- `simulator-management` — シミュレータ起動・消去・環境設定
- `session-management` — セッションデフォルト管理
- `project-discovery` — プロジェクト・ワークスペース・Swift Package の検出
- `project-scaffolding` — テンプレートからの新規プロジェクト生成
- `utilities` — ビルド成果物クリーン・管理
- `doctor` — 環境・依存関係の診断
- `workflow-discovery` — ランタイムでのワークフロー切替

## Step 3-2: 対話的設定（条件付き）

Step 3 質問2 の回答に基づき、必要なときのみ 2回目の AskUserQuestion を行う。**該当質問が 0 個なら AskUserQuestion を呼ばずに直接 Step 4 へ進む。**

### 質問3: シミュレータ選択（`simulator` ワークフロー選択時のみ）

`xcrun simctl list devices available` を実行し、利用可能なデバイスを抽出してリスト化する。上位3つを選択肢として提示する（最新の iPhone Pro モデルを `(Recommended)` に）。

- デバイスが見つからない場合は手動入力とする
- 選ばれた値は `simulatorName` に格納する。固定 UDID 指定が必要な場合のみ `simulatorId` に切り替える（通常は `simulatorName` を推奨）

### 質問4: プラットフォーム判定（iOS 以外と明確に分かる場合のみ）

以下のいずれかに該当する場合のみ確認する。それ以外は **iOS と仮定して質問しない**（`platform` フィールドは出力から省略する）:

- スキーム名や `xcodebuild -list` の SDK 情報に `macosx`, `watchos`, `xros`(visionOS), `appletvos` 等が含まれる
- ユーザーが事前に macOS / watchOS / visionOS / tvOS プロジェクトであると明示している
- `*.xcodeproj` のベース名に `Mac`, `Watch`, `Vision`, `TV` 等が含まれる（弱い根拠なので他と組合せ判断）

この質問は **iOS 以外がほぼ確実な場合のみ** 呼ぶため、選択肢に iOS は含めない（誤判定で iOS と分かった場合は「Other」で `iOS` を入力可能）。判定根拠から最も濃厚な候補を `(Recommended)` に付与する:

| platform | 説明 |
|---|---|
| macOS | Mac アプリ |
| watchOS | Apple Watch アプリ |
| visionOS | Apple Vision Pro アプリ |
| tvOS | Apple TV アプリ |

### 質問5: ビルド構成（質問しない方針）

`configuration` は **install フローでは質問せず**、XcodeBuildMCP のデフォルト（Debug）に任せる。Release ビルド検証など必要が生じたら、生成後の config.yaml を直接編集するか `/setup-xcodebuildmcp edit` で更新する。テンプレートには `# configuration: "Release"` をコメント例として残す。

## Step 4: config.yaml 生成

### 4-1. ディレクトリ作成

Bash で `.xcodebuildmcp/` ディレクトリを作成:

```bash
mkdir -p .xcodebuildmcp
```

### 4-2. config.yaml の生成

Write ツールで `.xcodebuildmcp/config.yaml` を生成する。以下のテンプレート（XcodeBuildMCP v2.5.1 schemaVersion: 1 準拠）を基に、Step 3 / Step 3-2 の回答を反映する:

```yaml
schemaVersion: 1

# 有効化するワークフロー（必要に応じて追加可能）
# 利用可能: simulator, device, macos, swift-package, ui-automation, debugging,
#          coverage, xcode-ide, simulator-management, session-management,
#          project-discovery, project-scaffolding, utilities, doctor, workflow-discovery
enabledWorkflows:
  - simulator        # Step 3 質問2 の選択結果（複数の場合は順に列挙）

# セッションデフォルト（プロジェクト単位の既定値）
sessionDefaults:
  scheme: "MyApp"                          # Step 3 質問1
  projectPath: "./MyApp.xcodeproj"         # または workspacePath（どちらか一方）
  # workspacePath: "./MyApp.xcworkspace"
  simulatorName: "iPhone 17"               # Step 3-2 質問3（simulator 選択時のみ）
  # simulatorId: "<UUID>"                  # 固定 UDID で指定したい場合
  # configuration: "Release"               # 既定は Debug。Release 検証時に有効化
  # platform: "macOS"                      # iOS 以外（macOS / watchOS / visionOS / tvOS）を使う場合のみ
  # useLatestOS: true                      # 既定で true。明示的に false にしたい場合のみ
  # bundleId: "com.example.MyApp"          # device / debugging で必要に応じて
  # deviceId: "<UUID>"                     # device ワークフロー利用時に固定したい場合
  # arch: "arm64"
  # derivedDataPath: "./.derivedData"
  # suppressWarnings: false
  # preferXcodebuild: false

# 任意の追加オプション（必要に応じて有効化）
# customWorkflows:
#   my-workflow:
#     - build_run_sim
#     - record_sim_video
#     - screenshot
# experimentalWorkflowDiscovery: false
# disableSessionDefaults: false
# incrementalBuildsEnabled: false
# debug: false
# sentryDisabled: false
# filePathRenderStyle: "list"   # "list" | "tree"
```

生成ルール:

- `enabledWorkflows`: Step 3 質問2 で選択されたワークフローを順に列挙
- `sessionDefaults`:
  - `scheme`: Step 3 質問1 の回答（必須）
  - `projectPath` または `workspacePath`: Step 2-1 の検出結果（**両方は含めない**）
  - `simulatorName`: Step 3-2 質問3 の回答（`simulator` ワークフロー選択時のみ実値で出力）
  - `platform`: Step 3-2 質問4 の回答が iOS 以外の場合のみ実値で出力。iOS の場合はコメント行のまま
  - `configuration` / `useLatestOS`: install フローでは質問しないため、テンプレートのコメント例のまま出力
  - `bundleId` / `deviceId` / `arch` / `derivedDataPath` / `suppressWarnings` / `preferXcodebuild`: コメント例のまま出力
- トップレベルの追加オプション（`customWorkflows` / `incrementalBuildsEnabled` / `debug` / `sentryDisabled` / `filePathRenderStyle` / `experimentalWorkflowDiscovery` / `disableSessionDefaults`）はコメント例のまま出力

### 4-3. 完了メッセージ

以下を表示する:

- 生成したファイルパス（`.xcodebuildmcp/config.yaml`）
- 生成した config.yaml の内容

## Step 5: 編集フロー（既存設定の更新）

### 5-1. 現在の設定の読み込み

`.xcodebuildmcp/config.yaml` を Read で読み込み、現在の設定を表示する。

### 5-2. 更新箇所の選択

AskUserQuestion（multiSelect: true）で更新したい箇所を選択させる（4択上限のため代表項目を提示。それ以外の項目は「Other」で項目名を直接指定可能）:

- スキーム / プロジェクトパス
- ワークフロー（`enabledWorkflows`）
- シミュレータ（`simulatorName` / `simulatorId`）
- ビルド構成（`configuration`）

「Other」で指定可能な追加項目の例: `platform`, `useLatestOS`, `bundleId`, `deviceId`, `arch`, `derivedDataPath`, `suppressWarnings`, `preferXcodebuild`, `incrementalBuildsEnabled`, `debug`, `sentryDisabled`, `filePathRenderStyle`, `customWorkflows`。

### 5-3. 選択項目の更新

選択された項目について、Step 3 / Step 3-2 と同じ要領で対話的に新しい値を確認する。

**現在値の提示方法**: AskUserQuestion にはデフォルト値を渡す機能がないため、各選択肢の `description` または質問文の末尾に `(現在: <現在値>)` の形式で現在値を併記する。例:

```
question: "scheme を更新します。新しい値を選択してください (現在: MyApp)"
options:
  - label: "MyApp-Dev"
    description: "Dev ターゲット用スキーム"
  - label: "MyAppTests"
    description: "テスト用スキーム"
```

### 5-4. 設定ファイルの更新

Edit ツールで変更箇所のみ更新する。**old_string の取り方ガイドライン**:

- **既存値の置換**: キー名と値を含めた行全体を `old_string` にする。例: `scheme: "MyApp"` → `scheme: "MyApp-Dev"`
- **コメント行の有効化（コメントから実値へ）**: `# configuration: "Release"` のような行全体を `old_string` にして、`configuration: "Release"` に置換
- **新規フィールドの追加**: 親キー（`sessionDefaults:` 等）の直後の最初の子要素を `old_string` の手がかりにし、そのすぐ前に新しい行を追加する形で挿入
- **配列要素の追加（`enabledWorkflows`）**: 既存の最後の要素行を `old_string` にして、その下に新要素を追加する形で置換

更新後、変更前後の差分を要約して表示し完了。

## Step 6: アンインストールフロー

### 6-1. 既存設定の確認

Glob で `.xcodebuildmcp/config.yaml` が存在するか確認する。

- 存在しない場合 → 「XcodeBuildMCP の設定は見つかりません」と表示して終了
- 存在する場合 → Read で内容を表示し、Step 6-2 へ

### 6-2. 削除確認

AskUserQuestion で確認する:

```
question: ".xcodebuildmcp/ ディレクトリを削除します。よろしいですか？"
options:
  - label: "キャンセル (Recommended)"
    description: "削除を中止する"
  - label: "削除する"
    description: ".xcodebuildmcp/ 以下を完全に削除する"
```

- 「キャンセル」→ 終了
- 「削除する」→ Step 6-3 へ

### 6-3. 設定ディレクトリの削除

Bash で `.xcodebuildmcp/` ディレクトリを削除:

```bash
rm -rf .xcodebuildmcp
```

### 6-4. 完了メッセージ

以下を表示する:

- 削除した内容（`.xcodebuildmcp/` ディレクトリ）
