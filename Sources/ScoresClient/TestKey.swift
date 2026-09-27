import Dependencies
import MomentumKit

extension ScoresClient: TestDependencyKey {
    /// Every endpoint is unimplemented: a test that calls one without
    /// overriding it fails.
    public static let testValue = Self()

    public static let previewValue = Self.sample
}

extension ScoresClient {
    /// Six scans of invented scores for the sample config's themes.
    public static var sample: Self { mock(SampleData.scores()) }

    public static func mock(_ rows: [ScoreRow]) -> Self {
        Self(fetchRecentScores: { rows })
    }

    public static func failing(_ error: any Error) -> Self {
        Self(fetchRecentScores: { throw error })
    }
}
