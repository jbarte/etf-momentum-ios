import BoardFeature
import Observation
import SignInFeature

// This import is what gives the app its live SignInClient and ScoresClient. The
// `DependencyKey` conformances in SupabaseLive are only found at runtime if the
// module is linked; without an import the linker may drop them, and the app
// silently falls back to the unimplemented test values.
import SupabaseLive

@MainActor
@Observable
public final class AppModel {
    // Child models are created in the parent's init, so any dependency
    // overrides wrapped around `AppModel()` flow down to them.
    public let session: SessionModel
    public let board: BoardModel

    public init() {
        let board = BoardModel()
        self.board = board
        // Every sign-out, voluntary or not, forgets the board on screen and on
        // disk: it is signed-in-only data.
        let session = SessionModel(onSignOut: { await board.reset() })
        self.session = session
        // A load that finds the session rejected ends it.
        board.onSessionExpired = { await session.sessionExpired() }
    }
}
