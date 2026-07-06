# Security Trust Model TODO

作成日: 2026-07-06
更新日: 2026-07-06
分類: Other
状態: Active

## 目的

任意の `.ogp` / HTML を開くと WKWebView で JS が実行される。preview のネットワークアクセス、`ogkiln` / MCP の書き込み範囲（path containment）、秘密情報の混入防止は思想（Design Constraints）に断片的に現れるが、信頼モデルとして明文化した仕様がない。信頼境界を確定し、spec 化する。

## スコープ

- 対象: editor preview での JS 実行・navigation・ネットワークアクセスの方針、`ogkiln` / MCP write の path containment（rootURL 配下限定、symlink、`--output`）、秘密情報混入の検査方針。
- 対象外: アプリ配布の署名・notarization（Release 運用の範囲）、Web 成果物のホスティング側セキュリティ（CSP 等は将来判断）。

## 人間側の意思決定

- 全体: 必要 - 信頼境界と preview のネットワーク方針を確定する。

## 草案（判断材料）

- preview JS: 実装 runtime（i18n、component 展開）が前提のため実行は許可する。その上で app sandbox / WKWebView の分離を信頼境界として明記し、開くファイルは「ユーザーが選んだリポジトリ」を信頼単位とする。
- navigation: canvas 内から外部 URL への遷移を許すか（ブロックして既定ブラウザへ委譲する案が有力）。
- network: preview の外部リソース読み込み（CDN font / 画像等）を許可 / 警告 / オプションで offline にするか。
- path containment: `ogkiln` / MCP の全 read / write を `rootURL` 配下に限定し、`../` エスケープと symlink 脱出を拒否する。`screenshot --output` / `build --output` の書き込み先の扱い（任意 path を許すか）を決める。
- 秘密情報: 「秘密情報を正本ファイルへ混ぜない」（Design Constraints）に対し、`.env` 等の混入を validation で警告する範囲を決める。`.ogp` にユーザー固有絶対パスを残さない検査も候補。

## 直列タスク

1. STM-001: 信頼境界とネットワーク方針を確定する
   - 人間判断: 必要 - preview の navigation / network 方針、containment の適用範囲（output 系の例外）、秘密情報検査の範囲を決める。blocking decision。
   - 内容: 現行実装の挙動（navigation、外部読み込み、path 検証）を棚卸しし、草案を確定して本文書へ反映する。
   - 完了条件: 信頼境界・各方針の決定が記録されている。
   - 確認方法: 文書確認。
2. STM-002: セキュリティモデルを spec 化する
   - 人間判断: 不要
   - 内容: `Docs/specs/` に信頼モデルを新規作成し、AgentInterface / OgkilnCLI / OpenGraphiteMCP へ containment 制約を反映する。
   - 完了条件: 信頼境界、preview 方針、containment 規則が仕様として読める。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。
3. STM-003: containment テストの実装 TODO を起票する
   - 人間判断: 不要
   - 内容: path traversal / symlink 脱出の拒否、navigation ブロック等の自動テストを整備する実装 TODO を起票する。
   - 完了条件: 実装 TODO が index に登録されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

## 参照

- [Design Philosophy](../../../specs/DesignPhilosophy.md)
- [Agent Interface](../../../specs/AgentInterface.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [OpenGraphite MCP](../../../specs/OpenGraphiteMCP.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
