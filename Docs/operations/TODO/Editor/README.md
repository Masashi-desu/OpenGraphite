# Editor TODO Index

更新日: 2026-07-06

SwiftUI editor、`.ogp` project loading、WKWebView canvas bridge、layers、selection、inspector、HTML write-back など、OpenGraphite editor 実行経路の残タスクを管理する。この index の順序は文書単位の直列実行順を示す。

## 直列ドキュメント

1. [Persistence Conflict Undo TODO](PersistenceConflictUndo.md): 保存パイプライン、外部変更との競合解決、複数ファイル横断の undo / redo 単位の方針を確定して spec 化する。
2. [HTML CSS Serialization Stability TODO](HtmlCssSerializationStability.md): 書き戻し時の diff 安定性（roundtrip、非編集領域の byte 保持、整形規則）の方針を確定して spec 化する。
3. [Ogp Schema Versioning TODO](OgpSchemaVersioning.md): `.ogp` スキーマの正本定義、未知キー保持、schemaVersion 互換・migration 方針を確定して spec 化する。
