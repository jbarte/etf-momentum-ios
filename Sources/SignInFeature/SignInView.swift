import SignInClient
import SwiftUI

/// Email, then "open the link we sent". The app finishes signing in when it is
/// opened from the link (`AppView`'s `onOpenURL`).
public struct SignInView: View {
    let model: SessionModel
    @State private var email = ""

    public init(model: SessionModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let sentTo = model.linkSentTo {
                    Section {
                        Text("Open the email on this iPhone and tap the link. It brings you back here, signed in.")
                        Button("Send another link") {
                            Task { await model.sendLink(to: sentTo) }
                        }
                        .disabled(model.isWorking)
                    } header: {
                        Text("Link sent to \(sentTo)")
                    } footer: {
                        Text("Only the newest link works, and only on the device that asked for it.")
                    }
                    Section {
                        Button("Use a different email") {
                            model.useDifferentEmail()
                        }
                    }
                } else {
                    Section {
                        TextField("you@example.com", text: $email)
                            .emailField()
                            .autocorrectionDisabled()
                        Button("Email me a sign-in link") {
                            Task { await model.sendLink(to: email) }
                        }
                        .disabled(email.isEmpty || model.isWorking)
                    } header: {
                        Text("Sign in")
                    } footer: {
                        Text("Access is invite-only.")
                    }
                }
                if model.isWorking {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                if let error = model.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("ETF Momentum")
        }
    }
}

// The package also builds for macOS, only so `swift test` runs on the Mac;
// these keyboard hints exist on iOS alone.
private extension View {
    func emailField() -> some View {
        #if os(iOS)
        self.keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}

// Each preview builds its own model inside the body, after the trait has
// overridden the dependency, so the model picks up the override.

private struct PreviewError: LocalizedError {
    var errorDescription: String? { "Signups not allowed for otp" }
}

#Preview("Email", traits: .dependency(\.signInClient, .signedOut())) {
    SignInView(model: SessionModel())
}

#Preview("Link sent", traits: .dependency(\.signInClient, .signedOut())) {
    let model = SessionModel()
    SignInView(model: model)
        .task { await model.sendLink(to: "you@example.com") }
}

#Preview("Not invited", traits: .dependency(\.signInClient, .failing(PreviewError()))) {
    let model = SessionModel()
    SignInView(model: model)
        .task { await model.sendLink(to: "stranger@example.com") }
}
