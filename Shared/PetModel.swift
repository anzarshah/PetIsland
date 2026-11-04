import SwiftUI

enum PetSpecies: String, Codable, CaseIterable, Identifiable, Sendable {
    case cat
    case dog

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var defaultName: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        }
    }
}

enum PetCoat: String, Codable, CaseIterable, Identifiable, Sendable {
    case honey
    case ash
    case midnight
    case snow
    case patches

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Shapes idle behaviour weights and some captions.
enum PetPersonality: String, Codable, CaseIterable, Identifiable, Sendable {
    case curious
    case cozy
    case bouncy

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var blurb: String {
        switch self {
        case .curious: "Explores, looks around, pokes at things."
        case .cozy: "Naps in sunbeams and grooms a lot."
        case .bouncy: "Runs, hops, and wants to play."
        }
    }
}

enum PetAccessory: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case collar
    case bandana
    case bow

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum GrowthStage: String, Codable, CaseIterable, Sendable {
    case baby
    case young
    case adult

    var title: String { rawValue.capitalized }
}

enum PetAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case pet
    case feed
    case play
    case groom
    case nap

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .pet: "hand.raised.fill"
        case .feed: "fork.knife"
        case .play: "figure.play"
        case .groom: "comb.fill"
        case .nap: "moon.zzz.fill"
        }
    }
}

enum NeedKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullness
    case energy
    case cleanliness
    case mood

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .fullness: "fork.knife"
        case .energy: "bolt.fill"
        case .cleanliness: "sparkles"
        case .mood: "heart.fill"
        }
    }

    /// The action that restores this need.
    var remedy: PetAction {
        switch self {
        case .fullness: .feed
        case .energy: .nap
        case .cleanliness: .groom
        case .mood: .play
        }
    }
}

/// What the pet is doing, as far as the Live Activity needs to know.
enum IslandState: String, Codable, Hashable, Sendable {
    case idle
    case happy
    case eating
    case playing
    case sleeping
    case attention
}

/// An 8-bit RGBA pixel. Pixel art is composed in these; `color` bridges to SwiftUI for the UI.
struct RGBA: Hashable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8 = 255

    init(hex: UInt32) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
    }

    var color: Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

/// Six colour roles per pet, lit from the upper left: outline, base, shadow (lower right),
/// highlight (upper left, belly and muzzle), marking (stripes or patches), eye. `accent` is the
/// pink of ears and noses.
struct CoatPalette: Sendable {
    var outline: RGBA
    var base: RGBA
    var shadow: RGBA
    var highlight: RGBA
    var marking: RGBA
    var eye: RGBA
    var accent = RGBA(hex: 0xF4A3B5)
    var hasStripes = false
    var hasPatches = false
}

extension PetCoat {
    func palette(for species: PetSpecies) -> CoatPalette {
        let ink = RGBA(hex: 0x2A2130)
        switch (self, species) {
        case (.honey, .cat):
            return CoatPalette(outline: ink, base: RGBA(hex: 0xF2A65A), shadow: RGBA(hex: 0xCF7A33), highlight: RGBA(hex: 0xFFE2BF), marking: RGBA(hex: 0xB85F22), eye: ink, hasStripes: true)
        case (.honey, .dog):
            return CoatPalette(outline: ink, base: RGBA(hex: 0xE9B96E), shadow: RGBA(hex: 0xC08A44), highlight: RGBA(hex: 0xFFEFD1), marking: RGBA(hex: 0xA8743A), eye: ink)
        case (.ash, _):
            return CoatPalette(outline: ink, base: RGBA(hex: 0xAEB3C2), shadow: RGBA(hex: 0x7C8295), highlight: RGBA(hex: 0xE8EAF1), marking: RGBA(hex: 0x6B7184), eye: ink)
        case (.midnight, _):
            return CoatPalette(outline: RGBA(hex: 0x15121C), base: RGBA(hex: 0x3F3D52), shadow: RGBA(hex: 0x2A2838), highlight: RGBA(hex: 0x7B7A9E), marking: RGBA(hex: 0x34324A), eye: RGBA(hex: 0xD6F56A))
        case (.snow, _):
            return CoatPalette(outline: RGBA(hex: 0x4A4358), base: RGBA(hex: 0xF2EEE8), shadow: RGBA(hex: 0xCFC7BC), highlight: RGBA(hex: 0xFFFFFF), marking: RGBA(hex: 0xDAD2C7), eye: RGBA(hex: 0x5FB2FF))
        case (.patches, .cat):
            return CoatPalette(outline: ink, base: RGBA(hex: 0xF6F1EA), shadow: RGBA(hex: 0xD5CCC0), highlight: RGBA(hex: 0xFFFFFF), marking: RGBA(hex: 0xE08A3E), eye: ink, hasPatches: true)
        case (.patches, .dog):
            return CoatPalette(outline: ink, base: RGBA(hex: 0xF6F1EA), shadow: RGBA(hex: 0xD5CCC0), highlight: RGBA(hex: 0xFFFFFF), marking: RGBA(hex: 0x6B4A33), eye: ink, hasPatches: true)
        }
    }
}

/// The app's pastel look, adaptive to light and dark appearance.
enum Pastel {
    static let background = Color(light: 0xFFF6E5, dark: 0x1C1826)
    static let card = Color(light: 0xFFFFFF, dark: 0x2A2538)
    static let peach = Color(light: 0xFFD9C2, dark: 0x5A3F3A)
    static let mint = Color(light: 0xCDEFE0, dark: 0x2E5247)
    static let sky = Color(light: 0xCFE4FF, dark: 0x2F4566)
    static let lavender = Color(light: 0xE4DCFF, dark: 0x3F3760)
    static let pink = Color(light: 0xFFD1DF, dark: 0x5E3A4A)
    static let butter = Color(light: 0xFFF0B8, dark: 0x5A5030)
    static let ground = Color(light: 0xE3C3A0, dark: 0x5B4A3A)
    static let ink = Color(light: 0x3B2E4A, dark: 0xF3EEFF)
    static let muted = Color(light: 0x6F6480, dark: 0xB8AFCB)
    static let coral = Color(light: 0xD9536E, dark: 0xFF8FA3)
    static let warning = Color(light: 0x9A5214, dark: 0xFFB86B)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A colour that adapts to the system appearance.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #else
        self.init(hex: light)
        #endif
    }
}
