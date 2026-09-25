import AppFeature
import SwiftUI

@main
struct ETFMomentumApp: App {
    @State private var model: AppModel

    init() {
        // Before AppModel exists, so the models it creates pick up stub-mode
        // overrides when the app is launched with -UseStubData.
        StubMode.prepareIfRequested()
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            AppView(model: model)
        }
    }
}
