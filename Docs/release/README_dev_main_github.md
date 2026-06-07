# dev/main と GitHub Release 運用

OpenGraphite では `dev` をリリース準備ブランチ、`main` を公開済みブランチとして扱います。`main` に存在しないリリースが `dev` に 1 つだけある状態で、ローカルから `dev` commit を対象に Git tag / GitHub Release / DMG asset を作成し、その後同じ commit を `main` へ fast-forward します。

当面の公式運用では、DMG は Git 管理に含めません。CI は DMG を再ビルド・署名・公証・upload せず、`dev` / `main` の品質ゲートと、`main` push 時の release policy 検証だけを担当します。ローカル環境で `.env` を使って署名・公証済み DMG を作成し、`dev` の CI 成功後に `gh release create` で GitHub Release asset として直接 upload します。

## バージョンと互換性

`project.yml` の `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` をアプリリリースバージョンの正本にします。現在のリリースバージョンは `0.1.0(1)` です。

PATCH、MINOR のバージョンアップデートでは互換性が維持されます。ただし PATCH の修正でやむを得ない場合は互換性を壊すことがあります。MAJOR アップデートは最適化のために互換性を犠牲にすることがあります。

メジャーバージョンが `0` の間は初期開発期間として互換性は常に無視され、最適化のために開発されます。初期開発期間は軽微な仕様変更を PATCH としてリリースします。

ビルド番号はリリース時に加算します。`dev` は次回リリース候補として `main` に対して `CURRENT_PROJECT_VERSION` を 1 だけ先行させます。

## 前提

- `project.yml` の `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` をリリースバージョンの正本にする
- `CURRENT_PROJECT_VERSION` は `main` より 1 だけ大きい整数にする
- リリースタグは `v<MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>)` 形式にする
- GitHub CLI (`gh`) で release 作成・asset upload ができる権限を持つ account に認証しておく
- 実プロジェクトの DMG 名が `OpenGraphite-<MARKETING_VERSION>.dmg` 以外になる場合は、Repository variables の `RELEASE_APP_NAME` で上書きする

## 1. ブランチ差分を確認する

```sh
git fetch origin --tags
BASE_REF=origin/main HEAD_REF=origin/dev ./Scripts/release/github/check_release_branch_policy.sh
```

`Release branch policy OK` が出ることを確認します。このチェックは次を検証します。

- `dev` が `main` から fast-forward 可能であること
- `dev` と `main` の間にリリースバージョン変更が 1 回だけあること
- `CURRENT_PROJECT_VERSION` が `main` より 1 だけ大きいこと

## 2. dev を push して CI を通す

リリース対象のコード、設定、ドキュメント、バージョン変更を `dev` に commit します。DMG は Git 管理に含めません。

```sh
git push origin dev
```

GitHub Actions の `Quality gate` が `dev` で成功したことを確認します。

## 3. DMG を dist に作成する

ローカル環境の `.env` に Developer ID と公証 credential を設定してから実行します。

```sh
./Scripts/release_dmg.zsh --output-dir dist
```

署名、公証、DMG 作成まで完了すると `dist/OpenGraphite-<MARKETING_VERSION>.dmg` が作成されます。DMG 作成と公証の詳細は `Docs/release/README_local_DMG.md` を参照してください。

## 4. dev commit から GitHub Release を作成する

`main` push 時の GitHub Actions は CI 上で DMG を再ビルド・署名・公証・upload しません。ローカルで署名・公証・実機検証まで終えたファイルを、Git 管理に含めずに GitHub Release asset として公開します。

`Scripts/release/github/publish_local_release.sh` は、現在の `dev` commit が `origin/dev` と一致していること、`dev` が `main` より build number で 1 だけ先行していること、release tag / GitHub Release が未作成であることを確認してから、GitHub Release と DMG asset を作成します。

```sh
./Scripts/release/github/publish_local_release.sh
```

DMG 名が既定と異なる場合は明示します。

```sh
./Scripts/release/github/publish_local_release.sh --dmg dist/OpenGraphite-<MARKETING_VERSION>.dmg
```

この手順では `dist/*.dmg` を `git add -f` しません。

## 5. main へ反映する

GitHub Release 作成後、同じ `dev` commit を `main` に fast-forward します。

```sh
git push origin HEAD:main
```

`.github/workflows/release.yml` は `main` への push を検知し、次を実行します。

1. push 後の `main` が `origin/dev` と同じコミットであることを検証する
2. branch policy とバージョン差分を検証する
3. `v<MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>)` の tag が `main` と同じ commit を指すことを検証する
4. 同じ tag の GitHub Release が存在し、draft ではないことを検証する
5. `OpenGraphite-<MARKETING_VERSION>.dmg` が Release asset として存在することを検証する

CI が署名・公証済み DMG を作成して release する方式は将来候補です。採用する場合は、個人 credential を使わず、専用証明書と GitHub Environment secret を用意したうえで別途 workflow を改訂します。

## 手動実行

GitHub Actions の `workflow_dispatch` から手動実行する場合は、通常は既定値のままで構いません。

- `base_ref`: `origin/main`
- `head_ref`: `origin/dev`

特定コミットを検証したい場合だけ SHA や tag を指定します。

## 失敗時の基本方針

`publish_local_release.sh` または `gh release create` の途中で失敗した場合は、GitHub の Releases と Tags を確認します。asset upload 途中の release や tag が残っている場合は、同じ `v<MARKETING_VERSION>(<CURRENT_PROJECT_VERSION>)` の release/tag を削除してから再実行してください。

`main` push 後の CI が release policy で失敗した場合は、次を確認します。

1. `origin/main` と `origin/dev` が同じ commit か
2. release tag がその commit を指しているか
3. GitHub Release が draft ではないか
4. `OpenGraphite-<MARKETING_VERSION>.dmg` が Release asset として存在するか
