import AppIntents
import SwiftUI
import WidgetKit

struct PetCaption: View {
    var name: String
    var caption: String
    var onDark: Bool
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(name)
                .font(.headline.weight(.heavy))
                .fontDesign(.rounded)
                .foregroundStyle(onDark ? .white : Pastel.ink)
            Text(caption)
                .font(.caption.weight(.medium))
                .fontDesign(.rounded)
                .foregroundStyle(onDark ? .white.opacity(0.75) : Pastel.muted)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// How long the visit has left; a system-driven countdown that needs no updates from the app.
struct VisitTimer: View {
    var attributes: PetAttributes
    var onDark: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .bold))
            Text(timerInterval: attributes.visitRange, countsDown: true, showsHours: true)
                .font(.caption2.monospacedDigit().weight(.semibold))
        }
        .fontDesign(.rounded)
        .foregroundStyle(onDark ? .white.opacity(0.6) : Pastel.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityLabel("Island visit ends in")
    }
}

struct PetLockScreenView: View {
    var attributes: PetAttributes
    var state: PetAttributes.ContentState
    var isStale: Bool

    static func restingCaption(for name: String) -> String {
        "\(name) is resting. Open the app to check in."
    }

    private var shownState: IslandState { isStale ? .sleeping : state.islandState }
    private var tint: Color { attributes.coat.palette(for: attributes.species).base.color }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button(intent: PetActionIntent(action: .pet)) {
                    CompactPetView(species: attributes.species, coat: attributes.coat, accessory: attributes.accessory, state: shownState)
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pet \(attributes.name)")

                VStack(alignment: .leading, spacing: 5) {
                    PetCaption(name: attributes.name, caption: isStale ? Self.restingCaption(for: attributes.name) : state.caption, onDark: false, alignment: .leading)
                    if let range = state.timedRange, range.upperBound > .now, !isStale {
                        ProgressView(timerInterval: range, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .progressViewStyle(.linear)
                        .tint(tint)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    IslandStatusGlyph(attributes: attributes, state: state, isStale: isStale)
                        .frame(height: 26)
                    VisitTimer(attributes: attributes, onDark: false)
                }
            }
            if !isStale {
                QuickActionButton(attributes: attributes, state: state, onDark: false)
            }
        }
        .padding(14)
    }
}
