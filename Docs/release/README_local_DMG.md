# **OpenGraphite** ローカルでの DMG 作成 & 公証

このテンプレートでは、DMG 作成と公証に必要な設定をリポジトリ直下の `.env` に寄せます。`.env.example` をコピーして各値を埋めれば、`Scripts/release_dmg.zsh` だけで Release ビルドから公証済み DMG の検証までを実行できます。

## 前提条件

- macOS 13 以降で Xcode（Command Line Tools を含む）がインストール済み
- Apple Developer Program に加入し、Developer ID Application 証明書をキーチェーンに追加済み
- Apple ID 用のアプリ用パスワード、または `notarytool` の keychain profile を用意済み
- `create-dmg` がインストール済み

```bash
brew install create-dmg
```

## 0) `.env` を用意する

```bash
cp .env.example .env
```

最低限、以下を自分の環境に合わせて設定してください。

- `RELEASE_SCHEME`
- `CODESIGN_IDENTITY`
- `CODESIGN_ENTITLEMENTS`（entitlements がないアプリでは空）
- `NOTARY_APPLE_ID` / `NOTARY_TEAM_ID` / `NOTARY_APP_PASSWORD`（Apple ID 認証を `.env` に直接置く場合）
- `NOTARY_PROFILE`（keychain profile を使う場合）

`.env` は shell で `source` できる書式を前提にしているため、値に空白が入る場合は必ずクオートしてください。`.env` は `.gitignore` 対象です。

公証 credential は、`NOTARY_APPLE_ID` / `NOTARY_TEAM_ID` / `NOTARY_APP_PASSWORD` の 3 つがそろっていれば `.env` 直指定を優先します。秘密情報を `.env` に置きたくない場合は、これらを空のままにして `NOTARY_PROFILE` を設定してください。

## 1) 一発実行する

```bash
./Scripts/release_dmg.zsh --output-dir dist
```

このコマンドは以下を順番に実行します。

1. `xcodegen generate`
2. Release ビルド
3. `.app` への codesign
4. `.app` の notarization / staple / validate / `spctl`
5. DMG 作成
6. `.dmg` への codesign
7. `.dmg` の notarization / staple / validate / `spctl`
8. 最終 DMG をマウントし、内包 `.app` の staple / `spctl` を再検証

出力先は既定で `dist/OpenGraphite-<version>.dmg` です。実際のファイル名は `.app` の `CFBundleName` と `CFBundleShortVersionString` から決まります。

## よく使うオプション

既存の `.app` を使う場合:

```bash
./Scripts/release_dmg.zsh --skip-build --app-path build/ReleaseDerivedData/Build/Products/Release/OpenGraphite.app
```

署名済み `.app` から DMG だけ作り直す場合:

```bash
./Scripts/release_dmg.zsh --skip-build --skip-sign --skip-notarize --app-path build/ReleaseDerivedData/Build/Products/Release/OpenGraphite.app
```

DMG 作成だけを実行する場合:

```bash
./Scripts/make_dmg.zsh --app-path build/ReleaseDerivedData/Build/Products/Release/OpenGraphite.app
```

## ローカルで公証

`Scripts/release_dmg.zsh` は、`.app` を単体で公証・staple してから DMG へ入れ、DMG 作成後に同じ `CODESIGN_IDENTITY` で DMG 自体へ署名してから DMG も公証します。最後に完成した DMG を読み取り専用でマウントし、中の `.app` に対しても `stapler validate` と `spctl --type execute` を実行します。

DMG だけを個別に公証する場合:

```bash
./Scripts/notarize_local.zsh dist/OpenGraphite-<version>.dmg
```

keychain profile を使う場合は、最初に 1 回だけ credential を保存します。

```bash
xcrun notarytool store-credentials "OpenGraphiteNotary" \
  --apple-id "<apple-id@example.com>" \
  --team-id "<TEAM ID>" \
  --password "<app-specific-password>"
```

作成後は `.env` に以下を設定します。

```bash
NOTARY_APPLE_ID=""
NOTARY_TEAM_ID=""
NOTARY_APP_PASSWORD=""
NOTARY_PROFILE="OpenGraphiteNotary"
```

profile の有効性は次のコマンドで確認できます。

```bash
xcrun notarytool history --keychain-profile "OpenGraphiteNotary"
```

## 公証をスキップする場合

Apple Developer Program に未加入などで公証できない場合は、DMG 作成だけを行い、テスターへ Gatekeeper の警告（「Apple は悪質なソフトウェアがないことを確認できません」）と回避手順（右クリック→「開く」）を必ず共有してください。

Developer ID 証明書がないローカル検証では、`.env` で `CODESIGN_IDENTITY="-"` を設定し、以下のように公証をスキップします。entitlements がないアプリでは `CODESIGN_ENTITLEMENTS=""` にしてください。

```bash
./Scripts/release_dmg.zsh --skip-notarize
```

## 出力確認

```bash
ls -lh dist/*.dmg
shasum -a 256 dist/*.dmg
```

生成された DMG のサイズと SHA-256 を控えておくと、配布後の検証が容易になります。

## AI アシスタントに依頼する際の指示テンプレート

1. `cd <repository-root>` でリポジトリ直下に移動させる。
2. `.env` の設定が済んでいることを確認させる。
3. `./Scripts/release_dmg.zsh --output-dir dist` を実行させ、各ステップのログと生成物を報告させる。
4. 公証を省略する場合は理由と回避手順を明記させる。
5. 生成された DMG のパス・サイズ・ハッシュの提示も依頼する。
6. 当面の GitHub Release 運用では、DMG を Git 管理に含めない。`dev` を push して CI 成功を確認後、`./Scripts/release/github/publish_local_release.sh` で GitHub Release asset へ直接 upload し、その後 `git push origin HEAD:main` を実行する。
