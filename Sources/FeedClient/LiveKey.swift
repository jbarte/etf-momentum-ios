import Dependencies
import Foundation
import MomentumKit

// The live value sits beside the interface: it is one URLSession call, not a
// dependency heavy enough to justify its own module (compare SupabaseLive).
extension FeedClient: DependencyKey {
    public static let liveValue = Self.live(
        url: URL(string: "https://jbarte.github.io/sector_momentum/data.json")!
    )

    /// Every endpoint is unimplemented: a test that calls one without
    /// overriding it fails.
    public static let testValue = Self()

    public static let previewValue = Self.sample

    /// URLSession's default cache honours GitHub Pages' ETag and max-age, so a
    /// repeat load revalidates instead of refetching.
    public static func live(url: URL, session: URLSession = .shared) -> Self {
        Self(fetchConfig: {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw FeedError.http(status: http.statusCode)
            }
            return try decode(data)
        })
    }

    public static var sample: Self { mock(SampleData.config) }

    public static func mock(_ config: FeedConfig) -> Self {
        Self(fetchConfig: { config })
    }

    public static func failing(_ error: any Error) -> Self {
        Self(fetchConfig: { throw error })
    }
}
