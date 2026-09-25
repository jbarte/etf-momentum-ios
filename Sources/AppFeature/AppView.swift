import BoardFeature
import SignInFeature
import SwiftUI

public struct AppView: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        switch model.session.state {
        case .checking:
            ProgressView()
                .task { await model.session.restore() }
        case .signedOut:
            SignInView(model: model.session)
        case .signedIn(let email):
            BoardView(model: model.board, email: email) {
                Task { await model.session.signOut() }
            }
            // The board found no usable session (e.g. a revoked refresh token).
            .onChange(of: model.board.outcome) { _, outcome in
                if outcome == .signedOut {
                    Task { await model.session.sessionExpired() }
                }
            }
        }
    }
}

// Uses each dependency's `previewValue`, so no overrides are needed: a
// signed-in session, a sample config and invented scores.
#Preview {
    AppView(model: AppModel())
}
