import SignInClient
import BoardCacheClient
import Dependencies
import FeedClient
import ScoresClient

public enum StubMode {
    public static let launchArgument = "-UseStubData"

    /// Call once at launch, before `AppModel()` is created. With the
    /// `-UseStubData` launch argument the app runs signed in, on a real config
    /// and invented scores, with nothing written to disk -- so it can be run
    /// in the simulator with no network and no sign-in.
    public static func prepareIfRequested(arguments: [String] = CommandLine.arguments) {
        guard arguments.contains(launchArgument) else { return }
        prepareDependencies {
            $0.signInClient = .signedIn(email: "stub@example.invalid")
            $0.scoresClient = .sample
            $0.feedClient = .sample
            $0.boardCacheClient = .inMemory()
        }
    }
}
