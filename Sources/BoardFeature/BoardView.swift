import BoardCacheClient
import FeedClient
import Foundation
import MomentumKit
import ScoresClient
import SwiftUI

public struct BoardView: View {
    let model: BoardModel
    let email: String
    let onSignOut: () -> Void
    @AppStorage("horizonKey") private var horizonKey = ""

    public init(model: BoardModel, email: String, onSignOut: @escaping () -> Void) {
        self.model = model
        self.email = email
        self.onSignOut = onSignOut
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("ETF Momentum")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Text(email)
                            Button("Sign out", role: .destructive, action: onSignOut)
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
                .refreshable { await model.load() }
                .task {
                    if model.outcome == nil { await model.load() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = model.snapshot, let board = model.board(horizonKey: horizonKey) {
            List {
                Section {
                    Picker("Horizon", selection: $horizonKey) {
                        ForEach(snapshot.config.horizons) { horizon in
                            Text(horizon.label).tag(horizon.key)
                        }
                    }
                    .pickerStyle(.segmented)
                    StatusBanner(board: board, cachedReason: model.cachedReason,
                                 isStale: model.isStale(board))
                }
                Section {
                    ForEach(boardItems(board.rows)) { item in
                        switch item {
                        case .row(let row): BoardRowView(row: row)
                        case .cut(let label): BandCutView(label: label)
                        }
                    }
                } header: {
                    Text("Scan #\(board.scanID) · \(ScanDate.day(board.runAt))")
                } footer: {
                    Text("\(board.horizon.label): buy the top \(board.horizon.topN), hold down to rank \(board.exitRank) of \(board.universeSize).")
                }
            }
            // Resolve an empty or retired saved preset to the one actually
            // shown, so the segmented control always has a selection -- on
            // first appearance, and again if a refresh brings a config where
            // the saved preset no longer exists.
            .onAppear { horizonKey = board.horizon.key }
            .onChange(of: board.horizon.key) { _, shown in horizonKey = shown }
        } else if case .failed(let message) = model.outcome {
            ContentUnavailableView {
                Label("Couldn't load the board", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
            }
        } else {
            ProgressView("Loading the board…")
        }
    }
}

/// Only shown when something is off: an old board, or an old scan.
struct StatusBanner: View {
    let board: Board
    let cachedReason: String?
    let isStale: Bool

    var body: some View {
        if let cachedReason {
            Label("Showing the last board you loaded. \(cachedReason)",
                  systemImage: "clock.arrow.circlepath")
                .font(.footnote)
                .foregroundStyle(.orange)
        } else if isStale {
            Label("Newest scan is from \(ScanDate.day(board.runAt)). The daily scan may not have run.",
                  systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }
}

// Each preview builds its own model inside the body, after the trait has
// overridden the dependency, so the model picks up the override. With no
// trait, every client uses its previewValue: a sample config, invented scores
// and an empty in-memory cache.

#Preview("Loaded") {
    BoardView(model: BoardModel(), email: "preview@example.invalid", onSignOut: {})
}

#Preview("Offline, showing cache", traits: .dependencies {
    $0.scoresClient = .failing(URLError(.notConnectedToInternet))
    $0.boardCacheClient = .inMemory(BoardSnapshot(config: SampleData.config, rows: SampleData.scores()))
}) {
    BoardView(model: BoardModel(), email: "preview@example.invalid", onSignOut: {})
}

#Preview("Stale scan", traits: .dependency(\.scoresClient, .mock(SampleData.scores(now: Date().addingTimeInterval(-3 * 86_400))))) {
    BoardView(model: BoardModel(), email: "preview@example.invalid", onSignOut: {})
}

#Preview("Failed", traits: .dependency(\.feedClient, .failing(FeedError.noConfig(schemaVersion: 1)))) {
    BoardView(model: BoardModel(), email: "preview@example.invalid", onSignOut: {})
}
