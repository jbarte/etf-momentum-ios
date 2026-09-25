import Dependencies
import Foundation
import MomentumKit

// The live value sits beside the interface: a file on disk does not justify
// its own module.
extension BoardCacheClient: DependencyKey {
    public static let liveValue = Self.file(
        URL.applicationSupportDirectory.appending(path: "last-board.json")
    )

    /// Every endpoint is unimplemented: a test that calls one without
    /// overriding it fails.
    public static let testValue = Self()

    public static let previewValue = Self.inMemory()

    public static func file(_ url: URL) -> Self {
        Self(
            load: {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(BoardSnapshot.self, from: data)
            },
            save: { snapshot in
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            },
            clear: {
                try? FileManager.default.removeItem(at: url)
            }
        )
    }

    /// Lives only as long as the process: previews, tests and stub mode.
    public static func inMemory(_ initial: BoardSnapshot? = nil) -> Self {
        let stored = LockIsolated(initial)
        return Self(
            load: { stored.value },
            save: { snapshot in stored.setValue(snapshot) },
            clear: { stored.setValue(nil) }
        )
    }
}
