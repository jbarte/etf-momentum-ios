import SignInClient
import SwiftUI

/// Email, then the code from the same email.
public struct SignInView: View {
    let model: SessionModel
    @State private var email = ""
    @State private var code = ""

    public init(model: SessionModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let sentTo = model.codeSentTo {
                    Section {
                        TextField("Code", text: $code)
                            .codeField()
                        Button("Sign in") {
                            Task { await model.verify(code: code) }
                        }
                        .disabled(!SessionModel.isPlausibleCode(code) || model.isWorking)
                    } header: {
                        Text("Code sent to \(sentTo)")
                    } footer: {
                        Text("The email also has a link for the website — here, type the code.")
                    }
                    Section {
                        Button("Use a different email") {
                            code = ""
                            model.useDifferentEmail()
                        }
                    }
                } else {
                    Section {
                        TextField("you@example.com", text: $email)
                            .emailField()
                            .autocorrectionDisabled()
                        Button("Send code") {
                            Task { await model.sendCode(to: email) }
                        }
                        .disabled(email.isEmpty || model.isWorking)
                    } header: {
                        Text("Sign in")
                    } footer: {
                        Text("Access is invite-only.")
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

    func codeField() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
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

#Preview("Email", traits: .dependency(\.signInClient, .signedOut)) {
    SignInView(model: SessionModel())
}

#Preview("Code", traits: .dependency(\.signInClient, .signedOut)) {
    let model = SessionModel()
    SignInView(model: model)
        .task { await model.sendCode(to: "you@example.com") }
}

#Preview("Not invited", traits: .dependency(\.signInClient, .failing(PreviewError()))) {
    let model = SessionModel()
    SignInView(model: model)
        .task { await model.sendCode(to: "stranger@example.com") }
}
