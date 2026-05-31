# Agent Interface Batch Editing TODO

作成日: 2026-05-31
更新日: 2026-05-31
分類: Other
状態: Active

## 目的

AI が OpenGraphite project のデザイン作業を高品質かつ再現可能に進められるように、`ogkiln` と OpenGraphite MCP にバッチ編集、dry-run、diff、整形、テンプレート適用を追加する。

## スコープ

- 対象: `.ogp` 経由で認知可能な project page、page node、CSS/HTML 断片に対する CLI/MCP 編集補助。
- 対象外: OpenGraphite.app の UI 操作追加、`.ogp` に登録されていない任意ファイルの暗黙編集、ユーザー編集済み sample の自動上書き。

## 人間側の意思決定

- 全体: 必要 - バッチ編集 schema と diff 表現を CLI/MCP の安定 API として確定する。

## 直列タスク

1. AIBE-001: バッチ編集 schema を定義する
   - 人間判断: 必要 - JSON/YAML のどちらを正本入力にするか、diff 出力を unified diff と構造化 JSON のどちらまで必須にするか決める。
   - 内容: `ogkiln batch` と MCP `apply_batch` が共有する operation schema を設計する。対象 operation は `project page add/create/place`、`node html insert/replace/delete/move/copy`、`node text set`、`node style set/remove`、`node attr set/remove`、`validate`、`screenshot page/node/canvas` とし、すべて `.ogp` の `pages[]` に登録された資源だけを対象にする。
   - 完了条件: `Docs/specs/OgkilnCLI.md` と `Docs/specs/OpenGraphiteMCP.md` に schema、失敗時の扱い、dry-run、diff、出力 JSON が明記されている。
   - 確認方法: 文書確認と `./Scripts/quality_gate.sh`。

2. AIBE-002: `ogkiln batch` の dry-run と diff を実装する
   - 人間判断: 不要
   - 内容: `ogkiln batch <project.ogp|current> --file <plan.json> [--dry-run] [--diff]` を追加する。dry-run ではファイルを書き込まず、対象解決、operation validation、予想差分、診断を返す。`--diff` は適用前後の HTML/.ogp 差分を出力する。
   - 完了条件: 単一 operation と複数 operation の dry-run が書き込みなしで成功し、存在しない page/node や `.ogp` 外 path を明確な error として返す。
   - 確認方法: Swift Testing の CLI/core tests と `./Scripts/quality_gate.sh`。

3. AIBE-003: `ogkiln batch` の transactional apply を実装する
   - 人間判断: 不要
   - 内容: すべての operation を事前検証し、途中失敗時に部分適用を残さない実行経路を実装する。HTML と `.ogp` を複数更新する場合も、書き込み順、backup、一時ファイル、rollback 方針を明示して実装する。
   - 完了条件: 複数ファイル更新の成功ケースと途中失敗ケースの tests があり、失敗時に対象ファイルが適用前状態へ戻る。
   - 確認方法: Swift Testing の transactional tests と `./Scripts/quality_gate.sh`。

4. AIBE-004: MCP に batch editing parity を追加する
   - 人間判断: 不要
   - 内容: OpenGraphite MCP に `apply_batch` を追加し、CLI と同じ schema、dry-run、diff、diagnostics を返す。MCP 経由でも `.ogp` scope 外の資源を暗黙編集できないようにする。
   - 完了条件: MCP server の tool schema と docs が更新され、CLI と同じ plan file を MCP request body に変換して同等結果を得られる。
   - 確認方法: `node --check MCP/OpenGraphite/server.mjs`、MCP unit/smoke test、`./Scripts/quality_gate.sh`。

5. AIBE-005: デザイン作業向けの整形とテンプレート適用を追加する
   - 人間判断: 必要 - HTML 断片の formatter 方針と reusable template の保管場所を決める。
   - 内容: 長い HTML 断片を安全に扱うため、`ogkiln fragment format`、`ogkiln template list/apply` 相当の機能を追加する。template apply は `.ogp` page/node を明示指定し、適用後に `validate` と任意の `screenshot` を連続実行できるようにする。
   - 完了条件: 一時断片を手作業で整形してから CLI に渡す必要が減り、template 適用後の diff、validate、screenshot path が JSON で返る。
   - 確認方法: CLI tests、sample project への dry-run smoke test、`./Scripts/quality_gate.sh`。

6. AIBE-006: バッチ編集を使ったデザイン改善ワークフローを文書化する
   - 人間判断: 不要
   - 内容: AI agent が `inspect -> graph -> screenshot -> batch dry-run -> diff review -> apply -> validate -> screenshot` の順に作業できる標準ワークフローを `Docs/specs/AgentInterface.md` と README に記載する。
   - 完了条件: CLI 単独、MCP 経由、OpenGraphite.app で開いている `current` project の 3 経路について、同じ `.ogp` scope を保つ利用例がある。
   - 確認方法: 文書確認、sample project での smoke command、`./Scripts/quality_gate.sh`。

## 参照

- [Agent Interface](../../../specs/AgentInterface.md)
- [Ogkiln CLI](../../../specs/OgkilnCLI.md)
- [OpenGraphite MCP](../../../specs/OpenGraphiteMCP.md)
- [TODO Document Governance](../GOVERNANCE.md)

## 運用メモ

- 完了したタスクは、残す理由がなければ削除する。
- 残タスクがなくなったら、この TODO 文書自体を削除する。
- 完了記録を残す必要がある場合は、`完了記録を残す理由` と削除予定を明記する。
