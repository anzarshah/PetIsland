import SwiftUI

/// Soft background with pastel blobs; adapts to light and dark.
struct PastelBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Pastel.background
            Circle().fill(Pastel.mint).frame(width: 320).blur(radius: 70).offset(x: -150, y: -260)
            Circle().fill(Pastel.peach).frame(width: 360).blur(radius: 80).offset(x: 170, y: 120)
            Circle().fill(Pastel.lavender).frame(width: 300).blur(radius: 80).offset(x: -120, y: 420)
        }
        .opacity(scheme == .dark ? 0.9 : 1)
        .ignoresSafeArea()
    }
}

/// A rounded card with a small uppercase title.
struct SectionCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Pastel.muted)
                .textCase(.uppercase)
                .tracking(1)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Pastel.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PrimaryButton: View {
    var title: String
    var symbol: String
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(role == .destructive ? Color.red.opacity(0.85) : Pastel.coral, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Static preview of a pet, used while adopting and when editing.
struct PetPreviewCard: View {
    var species: PetSpecies
    var coat: PetCoat
    var accessory: PetAccessory
    var name: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [Pastel.butter, Pastel.peach.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                Ellipse()
                    .fill(Pastel.ground)
                    .frame(width: 150, height: 26)
                    .offset(y: 62)
                CompactPetView(species: species, coat: coat, accessory: accessory, state: .idle)
                    .frame(width: 128, height: 128)
                    .offset(y: 4)
            }
            .frame(height: 190)
            .accessibilityElement()
            .accessibilityLabel("\(name), a \(coat.title.lowercased()) \(species.title.lowercased())")
            Text(name)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Pastel.ink)
        }
    }
}

struct SpeciesPicker: View {
    @Binding var selection: PetSpecies
    var coat: PetCoat

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PetSpecies.allCases) { species in
                let isSelected = species == selection
                let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
                Button {
                    selection = species
                } label: {
                    VStack(spacing: 8) {
                        CompactPetView(species: species, coat: coat, accessory: .none, state: isSelected ? .happy : .idle)
                            .frame(width: 64, height: 64)
                        Text(species.title)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Pastel.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(species == .cat ? Pastel.peach : Pastel.sky, in: shape)
                    .overlay(shape.strokeBorder(isSelected ? Pastel.ink : .clear, lineWidth: 2.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(species.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .animation(.snappy, value: selection)
    }
}

/// Coat swatches that wrap on narrow phones and at large text sizes.
struct CoatPicker: View {
    var species: PetSpecies
    @Binding var selection: PetCoat

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(PetCoat.allCases) { coat in
                let palette = coat.palette(for: species)
                let isSelected = coat == selection
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                Button {
                    selection = coat
                } label: {
                    VStack(spacing: 6) {
                        shape
                            .fill(palette.base.color)
                            .overlay(alignment: .topTrailing) {
                                shape.fill(palette.marking.color).frame(width: 16, height: 16).padding(5)
                            }
                            .overlay(alignment: .bottomLeading) {
                                Circle().fill(palette.highlight.color).frame(width: 12, height: 12).padding(6)
                            }
                            .overlay(shape.strokeBorder(isSelected ? Pastel.ink : palette.outline.color.opacity(0.35), lineWidth: isSelected ? 2.5 : 1))
                            .frame(width: 44, height: 44)
                        Text(coat.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? Pastel.ink : Pastel.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(coat.title) coat")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .animation(.snappy, value: selection)
    }
}

/// Accessory chips that wrap on narrow phones and at large text sizes.
struct AccessoryPicker: View {
    @Binding var selection: PetAccessory

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PetAccessory.allCases) { accessory in
                let isSelected = accessory == selection
                Button {
                    selection = accessory
                } label: {
                    Text(accessory.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.white : Pastel.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isSelected ? Pastel.coral : Pastel.background, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessory.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .animation(.snappy, value: selection)
    }
}

/// A linear meter for one need, with words as well as colour when it runs low.
struct NeedMeter: View {
    var kind: NeedKind
    var value: Double

    private var isLow: Bool { value < GameBalance.lowNeed }
    private var tint: Color { isLow ? Pastel.warning : Color(hex: 0x5FBF9A) }

    var body: some View {
        Gauge(value: value, in: 0...GameBalance.needMax) {
            HStack(spacing: 6) {
                Label(kind.title, systemImage: kind.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pastel.ink)
                Spacer()
                Text(isLow ? "Low · \(Int(value))%" : "\(Int(value))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isLow ? Pastel.warning : Pastel.muted)
            }
        }
        .gaugeStyle(.linearCapacity)
        .tint(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue(isLow ? "\(Int(value)) percent, low" : "\(Int(value)) percent")
    }
}

/// Short feedback after an action.
struct ToastView: View {
    var outcome: ActionOutcome

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: outcome.action.symbol)
                .font(.subheadline.weight(.bold))
            Text(outcome.message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            if outcome.bondGained > 0 {
                Text("+\(Int(outcome.bondGained)) bond")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Pastel.pink, in: Capsule())
            }
        }
        .foregroundStyle(Pastel.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Pastel.card, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}
