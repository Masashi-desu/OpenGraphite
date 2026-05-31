import Darwin
import Foundation

/// 論理名（日本語）: OpenGraphiteファイル変更監視
/// 概要: 表示中 HTML ファイルの外部変更を DispatchSource で監視します。
///
/// メソッド:
/// - `start(url:onChange:)`: 指定ファイルの変更監視を開始します。
/// - `cancel()`: 監視を停止します。
final class OpenGraphiteFileChangeMonitor {
    private var source: DispatchSourceFileSystemObject?

    deinit {
        cancel()
    }

    /// 論理名（日本語）: ファイル監視開始関数
    /// 処理概要: 指定 URL をイベント専用 file descriptor で開き、変更イベントを callback へ転送します。
    ///
    /// - Parameters:
    ///   - url: 監視対象ファイル URL。
    ///   - onChange: 変更検出時に呼び出す処理。
    func start(url: URL, onChange: @escaping () -> Void) {
        cancel()

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler(handler: onChange)
        source.setCancelHandler {
            close(descriptor)
        }
        self.source = source
        source.resume()
    }

    /// 論理名（日本語）: ファイル監視停止関数
    /// 処理概要: 現在の DispatchSource をキャンセルし、関連 file descriptor を閉じます。
    func cancel() {
        source?.cancel()
        source = nil
    }
}
