---
name: setup-xcodebuildmcp
description: XcodeBuildMCP の設定ファイル（.xcodebuildmcp/config.yaml）をプロジェクトに生成・セットアップする。xcodebuildmcp, config, setup, simulator, build, Xcode
argument-hint: [install|edit|uninstall]
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob
---

## Step 0: プランモード解除

プランモードが有効な場合は、ExitPlanMode ツールを呼び出して解除する。プランモードでない場合はスキップ。

## Step 1: 引数判定と前提確認

### 1-0. 引数ルーティング

- `$ARGUMENTS[0]` が `install` → Step 1-1 へ（前提確認後、Step 2 へ進む。Step 1-2 の既存設定確認では上書き or キャンセルのみ提示）
- `$ARGUMENTS[0]` が `edit` → Step 1-1 へ（前提確認後、Step 5 へ直行。config.yaml が存在しない場合は「設定がありません。`/setup-xcodebuildmcp install` を実行してください」と案内して終了）
- `$ARGUMENTS[0]` が `uninstall` → Step 6 へ直行（前提確認不要）
- 引数なし or 上記以外 → Step 1-1 へ（前提確認後、Step 1-2 で既存設定の有無により自動分岐）

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

- 存在する場合 → Read で内容を表示し、AskUserQuestion で「上書きする / 既存を編集する / キャンセル」を確認
  - 「上書き」→ Step 2 へ（新規作成と同じ流れ）
  - 「編集」→ Step 5（編集フロー）へ
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
- 両方ある場合 → AskUserQuestion でどちらを使うか選択させる（`.xcworkspace` を推奨として提示）
- どちらもない場合 → AskUserQuestion でパスを手動入力させる

### 2-2. スキーム一覧の取得

検出したプロジェクトに対して `xcodebuild -list` を実行し、利用可能なスキーム一覧を取得する。

- `-workspace` または `-project` オプションを 2-1 の結果に基づいて付与
- 取得成功 → スキーム一覧を Step 3 で使用
- 取得失敗 → スキームは手動入力とする

## Step 3: 対話的設定（基本）

1回目の AskUserQuestion で以下の2問を同時に確認する。

### 質問1: スキーム選択

- Step 2-2 でスキーム一覧が取得できた場合: 上位3つを選択肢として提示（4つ目は「Other」で手動入力可能）
- 取得できなかった場合: 手動入力を求める

### 質問2: ワークフロー選択（multiSelect: true）

以下から選択させる:

| ワークフロー | 説明 |
|---|---|
| simulator | シミュレータでのビルド・実行（推奨） |
| ui-automation | UI テスト自動化 |
| debugging | デバッグ機能 |
| xcode-ide | Xcode 26+ IDE 連携 |

## Step 3-2: 対話的設定（条件付き）

Step 3 質問2 の回答に基づき、追加の質問が必要な場合のみ 2回目の AskUserQuestion を行う。**不要なら Step 4 へスキップする。**

### 質問3: シミュレータ選択（simulator ワークフロー選択時のみ）

`xcrun simctl list devices available` を実行し、利用可能なデバイスを抽出してリスト化する。上位3つを選択肢として提示する。

- デバイスが見つからない場合は手動入力とする

### 質問4: プラットフォーム選択（macOS / watchOS / visionOS プロジェクトの可能性がある場合のみ）

Step 2-1 で検出したプロジェクト名や構成から iOS 以外のプラットフォームが想定される場合に確認する。明らかに iOS プロジェクトの場合はスキップ可。

| platform | 説明 |
|---|---|
| iOS | iPhone / iPad アプリ（デフォルト） |
| macOS | Mac アプリ |
| watchOS | Apple Watch アプリ |
| visionOS | Apple Vision Pro アプリ |

## Step 4: config.yaml 生成

### 4-1. ディレクトリ作成

Bash で `.xcodebuildmcp/` ディレクトリを作成:

```bash
mkdir -p .xcodebuildmcp
```

### 4-2. config.yaml の生成

Write ツールで `.xcodebuildmcp/config.yaml` を生成する。以下のテンプレートを基に、Step 3 の回答を反映する:

```yaml
schemaVersion: 1
enabledWorkflows:
  - simulator        # Step 3 の選択結果
sessionDefaults:
  scheme: "MyApp"           # Step 3 質問1 の回答
  projectPath: "./MyApp.xcodeproj"  # または workspacePath
  simulatorName: "iPhone 16 Pro"    # Step 3-2 質問3 の回答
  platform: "iOS"                   # Step 3-2 質問4 の回答
  useLatestOS: true
```

生成ルール:

- `enabledWorkflows`: Step 3 質問2 で選択されたワークフローのみ
- `sessionDefaults`:
  - `scheme`: Step 3 質問1 の回答
  - `projectPath` または `workspacePath`: Step 2-1 の検出結果（両方は含めない）
  - `simulatorName`: Step 3-2 質問3 の回答（simulator ワークフロー選択時のみ含める）
  - `platform`: Step 3-2 質問4 の回答（iOS 以外が選択された場合のみ含める。iOS の場合はデフォルトなので省略可）
  - `useLatestOS`: simulator ワークフローが含まれる場合は `true`

### 4-3. 完了メッセージ

以下を表示する:

- 生成したファイルパス（`.xcodebuildmcp/config.yaml`）
- 生成した config.yaml の内容

## Step 5: 編集フロー（既存設定の更新）

### 5-1. 現在の設定の読み込み

`.xcodebuildmcp/config.yaml` を Read で読み込み、現在の設定を表示する。

### 5-2. 更新箇所の選択

AskUserQuestion（multiSelect: true）で更新したい箇所を選択させる:

- スキーム
- ワークフロー
- シミュレータ
- プラットフォーム

### 5-3. 選択項目の更新

選択された項目について、Step 3 と同じ要領で対話的に新しい値を確認する。現在の値をデフォルトとして提示する。

### 5-4. 設定ファイルの更新

Edit ツールで変更箇所のみ更新する。変更前後の内容を表示して完了。

## Step 6: アンインストールフロー

### 6-1. 既存設定の確認

Glob で `.xcodebuildmcp/config.yaml` が存在するか確認する。

- 存在しない場合 → 「XcodeBuildMCP の設定は見つかりません」と表示して終了
- 存在する場合 → Read で内容を表示し、Step 6-2 へ

### 6-2. 削除確認

AskUserQuestion で「削除する / キャンセル」を確認する。

- 「キャンセル」→ 終了

### 6-3. 設定ディレクトリの削除

Bash で `.xcodebuildmcp/` ディレクトリを削除:

```bash
rm -rf .xcodebuildmcp
```

### 6-4. 完了メッセージ

以下を表示する:

- 削除した内容（`.xcodebuildmcp/` ディレクトリ）
