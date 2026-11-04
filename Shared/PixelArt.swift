import CoreGraphics
import Foundation

/// A sprite is a grid of characters, one per pixel.
typealias Sprite = [String]

/// Props that accompany a pose or an action.
enum PetProp {
    case heart, zzz, fish, bone, yarn, ball, sparkle, comb

    static func prop(for state: IslandState, species: PetSpecies) -> PetProp? {
        switch (state, species) {
        case (.happy, _): .heart
        case (.sleeping, _): .zzz
        case (.eating, .cat): .fish
        case (.eating, .dog): .bone
        case (.playing, .cat): .yarn
        case (.playing, .dog): .ball
        case (.idle, _), (.attention, _): nil
        }
    }

    static func prop(for action: PetAction, species: PetSpecies) -> PetProp {
        switch (action, species) {
        case (.pet, _): .heart
        case (.nap, _): .zzz
        case (.groom, _): .comb
        case (.feed, .cat): .fish
        case (.feed, .dog): .bone
        case (.play, .cat): .yarn
        case (.play, .dog): .ball
        }
    }
}

/// A small RGBA canvas that sprites are blitted into, one cell per pixel.
struct PixelBuffer {
    let width: Int
    let height: Int
    private var pixels: [RGBA?]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: nil, count: width * height)
    }

    mutating func set(_ x: Int, _ y: Int, _ color: RGBA) {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return }
        pixels[y * width + x] = color
    }

    func get(_ x: Int, _ y: Int) -> RGBA? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        return pixels[y * width + x]
    }

    mutating func blit(_ sprite: Sprite, at x: Int, _ y: Int, colors: (Character) -> RGBA?) {
        for (row, line) in sprite.enumerated() {
            for (column, character) in line.enumerated() {
                if let color = colors(character) {
                    set(x + column, y + row, color)
                }
            }
        }
    }

    mutating func flipHorizontally() {
        for y in 0..<height {
            let range = (y * width)..<((y + 1) * width)
            pixels.replaceSubrange(range, with: pixels[range].reversed())
        }
    }

    func cgImage() -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (index, pixel) in pixels.enumerated() {
            guard let pixel else { continue }
            bytes[index * 4] = pixel.r
            bytes[index * 4 + 1] = pixel.g
            bytes[index * 4 + 2] = pixel.b
            bytes[index * 4 + 3] = pixel.a
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(.byteOrder32Big)
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: space, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}

/// Shared pixel colours and the image cache used by every sprite composer.
enum PixelArt {
    static let white = RGBA(hex: 0xFFFFFF)
    static let collar = RGBA(hex: 0xE9627C)
    static let bandana = RGBA(hex: 0x5FA8E6)
    static let bow = RGBA(hex: 0xF07AA0)

    static let propColors: [Character: RGBA] = [
        "h": RGBA(hex: 0xFF7A9E), "w": white, "z": RGBA(hex: 0x9FCBFF), "f": RGBA(hex: 0x79B8FF), "e": RGBA(hex: 0x2A2130),
        "o": RGBA(hex: 0xFFF4E0), "y": RGBA(hex: 0x5ED3C3), "g": RGBA(hex: 0xBFF2EA), "a": RGBA(hex: 0xDCEF6A),
        "x": RGBA(hex: 0xFFD966), "v": RGBA(hex: 0xF7B2C6), "u": RGBA(hex: 0xD98AA6), "k": RGBA(hex: 0xC9A27A),
        "q": RGBA(hex: 0x8C6A48), "!": RGBA(hex: 0xFF8C5A), "s": RGBA(hex: 0xD9D2C7),
    ]

    private static let cache = NSCache<NSString, CGImage>()

    static func cached(_ key: String, _ make: () -> PixelBuffer) -> CGImage {
        let nsKey = key as NSString
        if let hit = cache.object(forKey: nsKey) { return hit }
        guard let image = make().cgImage() else {
            preconditionFailure("Could not rasterize \(key)")
        }
        cache.setObject(image, forKey: nsKey)
        return image
    }

    /// Maps a coat sprite letter to its colour.
    static func coatColor(_ character: Character, palette: CoatPalette, species: PetSpecies, blushing: Bool = false, mouthOpen: Bool = false, tongue: Bool = false) -> RGBA? {
        switch character {
        case "#": palette.outline
        case "b": palette.base
        case "d": palette.shadow
        case "h", "l": palette.highlight
        case "s": palette.hasStripes ? palette.marking : palette.base
        case "q": palette.hasPatches ? palette.marking : palette.base
        case "e": palette.eye
        case "w": white
        case "n": species == .dog ? palette.outline : palette.accent
        case "p": palette.accent
        case "k": blushing ? palette.accent : palette.base
        case "m", "o": mouthOpen || species == .dog ? palette.outline : palette.highlight
        case "t": tongue ? palette.accent : palette.base
        case "c": collar
        default: nil
        }
    }

    /// A prop on its own, for status glyphs and buttons.
    static func prop(_ prop: PetProp) -> CGImage {
        cached("prop/\(prop)") {
            switch prop {
            case .heart: return single(PetSprites.heart)
            case .fish: return single(PetSprites.fish)
            case .bone: return single(PetSprites.bone)
            case .yarn: return single(PetSprites.yarn)
            case .ball: return single(PetSprites.ball)
            case .sparkle: return single(PetSprites.sparkleBig)
            case .comb: return single(PetSprites.comb)
            case .zzz:
                var buffer = PixelBuffer(width: 7, height: 7)
                buffer.blit(PetSprites.zBig, at: 3, 0) { propColors[$0] }
                buffer.blit(PetSprites.zSmall, at: 0, 4) { propColors[$0] }
                return buffer
            }
        }
    }

    static func single(_ sprite: Sprite) -> PixelBuffer {
        var buffer = PixelBuffer(width: sprite[0].count, height: sprite.count)
        buffer.blit(sprite, at: 0, 0) { propColors[$0] }
        return buffer
    }
}
