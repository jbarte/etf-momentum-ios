import MomentumKit
import SwiftUI

struct BoardRowView: View {
    let row: BoardRow

    var body: some View {
        HStack(spacing: 12) {
            Text(row.rankText)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .frame(width: 32, height: 32)
                .background(Circle().fill(row.inBuyBand ? Color.green.opacity(0.18)
                                                        : Color.secondary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.theme)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    // No Enter prompt for a theme there is no way to buy
                    // (rescore.js badgeFor); Exit still applies.
                    if let setup = row.setup, !(setup == .entry && row.unbuyable) {
                        SetupBadge(setup: setup)
                    }
                }
                HStack(spacing: 6) {
                    if let ticker = row.ticker {
                        Text(ticker).font(.caption.monospaced())
                    }
                    Text("\(row.trajectory.glyph) \(row.trajectory.word)")
                    if row.unbuyable {
                        Text("⊘ not buyable in EU")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    DivergingBar(value: row.composite)
                        .frame(width: 56, height: 8)
                    Text(signedText(row.composite))
                        .font(.subheadline.monospacedDigit())
                }
                HStack(spacing: 4) {
                    Text("L").font(.caption2).foregroundStyle(.secondary)
                    DivergingBar(value: row.level).frame(width: 28, height: 5)
                    Text("C").font(.caption2).foregroundStyle(.secondary)
                    DivergingBar(value: row.change).frame(width: 28, height: 5)
                }
                Text(deltaLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(deltaColor)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var deltaLabel: String {
        switch row.deltaDirection {
        case .up: "▲ \(row.deltaText)"
        case .down: "▼ \(row.deltaText)"
        case .none: row.deltaText
        }
    }

    private var deltaColor: Color {
        switch row.deltaDirection {
        case .up: .green
        case .down: .red
        case .none: .secondary
        }
    }
}

struct SetupBadge: View {
    let setup: Setup

    var body: some View {
        let color: Color = setup == .entry ? .green : .red
        Text(setup == .entry ? "Enter" : "Exit")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

/// A signed value drawn from the centre out on a FIXED scale (BarScale): a
/// left-filled bar would draw -0.7 and +0.7 identically.
struct DivergingBar: View {
    let value: Double?

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                if let value, let fraction = BarScale.fraction(value) {
                    let width = max(half * fraction, 1)
                    Capsule()
                        .fill(value >= 0 ? Color.green : Color.red)
                        .frame(width: width)
                        .offset(x: value >= 0 ? half : half - width)
                }
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 1)
                    .offset(x: half)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The web's "BUY BAND ENDS" / "HOLD BAND ENDS" rows.
struct BandCutView: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            rule
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .fixedSize()
            rule
        }
        .listRowBackground(Color.clear)
    }

    private var rule: some View {
        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
    }
}
