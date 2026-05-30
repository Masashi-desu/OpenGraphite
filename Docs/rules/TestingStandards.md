# 🧪 テストコード記述規約（Swift Testing）

本ドキュメントは、本プロジェクトにおける **Swift Testing（Swift 5.9〜）ベースのテストコード記述規約** を定めたものです。
@Suite / @Test アトリビュートを使用し、日本語コメントで意図が明確なテスト記述を行うことを目的とします。

---

## 📘 基本方針

- すべてのテストコードには、論理名（日本語）と概要を `///` コメントで明示する。
- テスト関数内部では、以下コメントを当該ステップ上部に必ず記載する。
  ```
  // コンディション：〜のとき（Given）
  // 検証内容：〜したら（When）
  // 期待値：〜になる（Then）
  ```
- `#expect()` を使用し、条件を明確に記述する。
- 正常系（成功パターン）と異常系（例外パターン）の両方を用意することを推奨する。

---

## 📁 ディレクトリ構成ルール

```
ProjectRoot/
├─ Sources/
│  └─ App/
│     ├─ Models/
│     │  └─ SampleManager.swift
│     └─ ViewModels/
│        └─ MainViewModel.swift
└─ Tests/
   └─ AppTests/
      ├─ Models/
      │  └─ SampleManager_test.swift
      └─ ViewModels/
         └─ MainViewModel_test.swift
```

### 命名・構造ルール

| 項目 | 方針 |
|------|------|
| **ファイル名** | 対応元ソース + `_test.swift` |
| **スイート名** | `<対象名>Tests` とする |
| **コメント形式** | 本規約準拠の日本語ドキュメントコメント |
| **テスト単位** | 各メソッドまたは機能単位ごとに1関数以上定義 |
| **異常系** | 例外・エラーを想定したテストを別関数で定義 |

---

## ✅ 正常系テストの例

```swift
/// 論理名（日本語）: サンプルテスト関連のテストスイート
/// 概要: 各テストケースでサンプル機能の基本動作とエラーハンドリングを確認します。
@Suite("サンプルテスト関連のテストスイート")
struct SampleTests {

    /// 論理名（日本語）: サンプルの基本動作テスト
    /// 概要: 正常系の動作を確認し、結果が期待値通りになることを検証します。
    @Test("サンプルテスト")
    func testSample() throws {
        // コンディション：初期状態で設定値が有効な場合
        let manager = SampleManager(isEnabled: true)

        // 検証内容：メソッドを実行した際の返り値を確認
        let result = manager.performAction()

        // 期待値：戻り値が true になる
        #expect(result == true)
    }
}

/// テスト対象の簡易サンプル実装
struct SampleManager {
    var isEnabled: Bool

    func performAction() -> Bool {
        // 有効な場合はtrue、無効ならfalseを返す
        return isEnabled
    }
}
```

---

## ❌ 異常系テストの例（例外発生時）

```swift
/// 論理名（日本語）: サンプルテスト関連のテストスイート
/// 概要: エラーが発生するケースを含めた挙動を確認します。
@Suite("サンプルテスト関連のテストスイート")
struct SampleErrorTests {

    /// 論理名（日本語）: 無効状態での例外テスト
    /// 概要: 無効な設定でメソッドを実行した際に例外が発生することを確認します。
    @Test("サンプル異常系テスト")
    func testSampleThrowsError() throws {
        // コンディション：設定値が無効（false）の場合
        let manager = SampleManager(isEnabled: false)

        // 検証内容：メソッド実行時に例外が発生するか確認
        #expect(throws: SampleError.invalidState) {
            _ = try manager.performActionWithThrow()
        }

        // 期待値：SampleError.invalidState が発生する
    }
}

/// エラー定義
enum SampleError: Error {
    case invalidState
}

/// テスト対象の簡易サンプル実装（例外発生バージョン）
struct SampleManager {
    var isEnabled: Bool

    func performActionWithThrow() throws -> Bool {
        guard isEnabled else {
            throw SampleError.invalidState
        }
        return true
    }
}
```

---

## 🧭 補足ルール

- **テストケース命名規則**: `test<対象メソッド名><条件>` の形式を推奨（例：`testPerformAction_WhenDisabled()`）。
- **コメント整形**: `//` の後に半角スペースを入れる。
- **スイートコメント**: 上部に論理名・概要を必ず記載する。
- **共通ユーティリティ**: 繰り返し使用されるテストデータ生成関数やモックは `Tests/Utilities/` に配置する。

---

## 🧩 まとめ

この規約の目的は以下の3点です：

1. **テスト意図の明確化** — 日本語コメントによりチーム全員が理解可能
2. **構造の一貫性** — SwiftPM／Xcode両対応のディレクトリ階層
3. **保守性向上** — 正常系・異常系双方の明確なテスト責務分離
