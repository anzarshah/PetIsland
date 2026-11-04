import AppIntents
import SwiftUI

/// Draws a pixel-art image with nearest-neighbour scaling so every pixel stays crisp.
struct PixelImage: View {
    var image: CGImage

    var body: some View {
        Image(decorative: image, scale: 1)
            .interpolation(.none)
            .antialiased(false)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

/// The hand-drawn 16×16 island sprite for a pet in a state.
struct CompactPetView: View {
    var species: PetSpecies
    var coat: PetCoat
    var accessory: PetAccessory
    var state: IslandState

    var body: some View {
        PixelImage(image: PixelArt.compact(species: species, coat: coat, accessory: accessory, state: state))
    }
}

/// One useful status beside the pet: the prop for what it is doing (with a system-driven ring
/// while the action lasts), an attention mark when a need is low, or the lowest need's value.
struct IslandStatusGlyph: View {
    var attributes: PetAttributes
    var state: PetAttributes.ContentState
    var isStale = false

    var body: some View {
        if isStale {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Resting")
        } else if let prop = PetProp.prop(for: state.islandState, species: attributes.species) {
            if let range = state.timedRange, range.upperBound > .now {
                ProgressView(timerInterval: range, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(attributes.coat.palette(for: attributes.species).base.color)
                .overlay { PixelImage(image: PixelArt.prop(prop)).padding(6) }
                .accessibilityLabel(Text(state.islandState.rawValue.capitalized))
            } else {
                PixelImage(image: PixelArt.prop(prop)).padding(3)
                    .accessibilityLabel(Text(state.islandState.rawValue.capitalized))
            }
        } else if state.islandState == .attention {
            Image(systemName: state.lowestNeed.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0xFF8C5A))
                .accessibilityLabel("\(state.lowestNeed.title) low")
        } else {
            NeedPip(kind: state.lowestNeed, value: state.lowestValue)
        }
    }
}

/// A tiny gauge: the pet's lowest need as a ring with its symbol inside.
struct NeedPip: View {
    var kind: NeedKind
    var value: Int

    private var tint: Color { value < Int(GameBalance.lowNeed) ? Color(hex: 0xFF8C5A) : Color(hex: 0x7ED3B2) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(value) / GameBalance.needMax)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: kind.symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(kind.title) \(value) percent")
    }
}

/// The single most useful care action right now, as one prominent intent button.
struct QuickActionButton: View {
    var attributes: PetAttributes
    var state: PetAttributes.ContentState
    var onDark = true

    private var tint: Color { attributes.coat.palette(for: attributes.species).base.color }

    var body: some View {
        let action = state.suggestedAction
        Button(intent: PetActionIntent(action: action)) {
            HStack(spacing: 6) {
                PixelImage(image: PixelArt.prop(PetProp.prop(for: action, species: attributes.species)))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                Text(label(for: action))
                    .font(.caption.weight(.bold))
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(onDark ? tint.opacity(0.28) : tint.opacity(0.4), in: Capsule())
            .foregroundStyle(onDark ? .white : Pastel.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: action))
    }

    private func label(for action: PetAction) -> String {
        switch action {
        case .feed: "Feed \(attributes.name)"
        case .play: "Play with \(attributes.name)"
        case .groom: "Groom \(attributes.name)"
        case .nap: "Tuck \(attributes.name) in"
        case .pet: "Pet \(attributes.name)"
        }
    }
}

/// Care buttons that run `PetActionIntent`, so they work in the Dynamic Island, on the Lock
/// Screen, and inside the app. Petting is done by tapping the pet itself.
struct PetActionBar: View {
    var species: PetSpecies
    var tint: Color
    var actions: [PetAction] = [.feed, .play, .groom, .nap]
    var onDark = true
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                Button(intent: PetActionIntent(action: action)) {
                    HStack(spacing: 5) {
                        PixelImage(image: PixelArt.prop(PetProp.prop(for: action, species: species)))
                            .frame(width: compact ? 12 : 14, height: compact ? 12 : 14)
                            .accessibilityHidden(true)
                        Text(action.title)
                            .font((compact ? Font.caption2 : Font.caption).weight(.bold))
                            .fontDesign(.rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 6 : 8)
                    .background(onDark ? tint.opacity(0.22) : tint.opacity(0.35), in: Capsule())
                    .foregroundStyle(onDark ? .white : Pastel.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(action.title))
            }
        }
    }
}
