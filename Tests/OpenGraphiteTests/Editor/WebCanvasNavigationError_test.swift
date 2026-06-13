import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: WebCanvas navigation error関連のテストスイート
/// 概要: WebView の再読み込み競合で発生する一時的な navigation error だけを抑止することを確認します。
@Suite("WebCanvas navigation error関連のテストスイート")
struct WebCanvasNavigationErrorTests {
    /// 論理名（日本語）: キャンセルnavigationエラー抑止テスト
    /// 概要: 同一 URL の再読み込み競合で発生する NSURLErrorCancelled を alert 対象から外すことを検証します。
    @Test("NSURLErrorCancelledを抑止対象にする")
    func testShouldSuppressNavigationErrorForCancelledNavigation() {
        // コンディション：WebKit が既存 navigation のキャンセルとして返す URL error を用意する（Given）
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)

        // 検証内容：WebCanvas の navigation error 抑止判定を実行する（When）
        let shouldSuppress = WebCanvasView.Coordinator.shouldSuppressNavigationError(error)

        // 期待値：正常な再読み込み競合として alert 表示対象から外れる（Then）
        #expect(shouldSuppress == true)
    }

    /// 論理名（日本語）: Frame load interruptedエラー抑止テスト
    /// 概要: WebKit の Frame load interrupted を外部変更同期中の一時的な中断として扱うことを検証します。
    @Test("Frame load interruptedを抑止対象にする")
    func testShouldSuppressNavigationErrorForFrameLoadInterrupted() {
        // コンディション：WebKit が frame load interrupted として返す navigation error を用意する（Given）
        let error = NSError(
            domain: "WebKitErrorDomain",
            code: 102,
            userInfo: [NSLocalizedDescriptionKey: "Frame load interrupted"]
        )

        // 検証内容：WebCanvas の navigation error 抑止判定を実行する（When）
        let shouldSuppress = WebCanvasView.Coordinator.shouldSuppressNavigationError(error)

        // 期待値：正常な再読み込み競合として alert 表示対象から外れる（Then）
        #expect(shouldSuppress == true)
    }

    /// 論理名（日本語）: 通常navigationエラー表示対象テスト
    /// 概要: 実際の読み込み失敗を一時的な中断として誤って抑止しないことを検証します。
    @Test("通常の読み込み失敗は抑止しない")
    func testShouldSuppressNavigationErrorKeepsRealFailuresVisible() {
        // コンディション：実際の読み込み失敗を表す URL error を用意する（Given）
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist)

        // 検証内容：WebCanvas の navigation error 抑止判定を実行する（When）
        let shouldSuppress = WebCanvasView.Coordinator.shouldSuppressNavigationError(error)

        // 期待値：alert 表示対象として残る（Then）
        #expect(shouldSuppress == false)
    }
}
