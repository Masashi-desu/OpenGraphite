# Codex グローバルカスタムプロンプト

- 返信は特段の指示がない限りすべて自然な日本語で行うこと。
- 技術用語やコマンド名は必要に応じて原語（英語）を併記してよい。
- ユーザーが別言語での回答を明示的に求めた場合のみ、その指示に従う。
- ログやコード片など引用部分は原文を尊重しつつ、必要があれば簡潔な日本語の補足を加える。
- リポジトリ直下の `README.md` を参照し、プロジェクトの規約について記述があった場合は厳守する。

## OpenGraphite 作業ルール

- `project.yml` を XcodeGen の正本として扱い、`OpenGraphite.xcodeproj` は生成物として直接編集しない。
- Swift コードを追加・変更する場合は `Docs/rules/DocumentCommentStandards.md` に従い、主要な型と関数へ `///` ドキュメントコメントを付与する。
- テストを追加・変更する場合は `Docs/rules/TestingStandards.md` に従い、Swift Testing の `@Suite` / `@Test` と Given/When/Then コメントを用いる。
- TODO 文書を追加・更新する場合は `Docs/operations/TODO/GOVERNANCE.md` と `Docs/operations/TODO/TEMPLATE.md` に従い、残タスクだけを直列化して管理する。
- コード、設定、ドキュメント生成に関わる変更を完了する前に、品質ゲート `./Scripts/quality_gate.sh` を必ず完走させる。
- 品質ゲートが失敗した状態で作業を完了してはならない。外部要因で実行できない場合のみ、理由と未確認範囲を明記してユーザーへ報告する。
