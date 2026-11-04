import CoreGraphics
import Foundation

/// Assembles one 24×24 frame from a rig and a `PetFrame`: far legs, body, tail, near legs, head,
/// accessory, bowl, particles. Everything lands on whole pixels; nothing is scaled or blended.
enum PetSpriteComposer {
    static let canvas = 24
    /// Row the feet rest on.
    static let ground = 21

    static func render(species: PetSpecies, coat: PetCoat, accessory: PetAccessory, stage: GrowthStage, frame: PetFrame, facingRight: Bool) -> CGImage {
        let key = "frame/\(species.rawValue)/\(coat.rawValue)/\(accessory.rawValue)/\(stage.rawValue)/\(facingRight)/\(frame.cacheKey)"
        return PixelArt.cached(key) {
            compose(species: species, palette: coat.palette(for: species), accessory: accessory, rig: PetRig.rig(for: species, stage: stage), frame: frame, facingRight: facingRight)
        }
    }

    static func compose(species: PetSpecies, palette: CoatPalette, accessory: PetAccessory, rig: PetRig, frame: PetFrame, facingRight: Bool) -> PixelBuffer {
        var buffer = PixelBuffer(width: canvas, height: canvas)
        guard let body = rig.bodies[frame.posture] else { return buffer }
        let dy = frame.dy

        // Far legs sit behind the body in shadow.
        drawLegs(&buffer, far: true, body: body, rig: rig, frame: frame, palette: palette)

        buffer.blit(body.sprite, at: body.origin.x, body.origin.y + dy) { character in
            PixelArt.coatColor(character, palette: palette, species: species)
        }

        if let tail = rig.tails[frame.tail] {
            let origin = PixelPoint(x: body.tail.x - tail.join.x, y: body.tail.y - tail.join.y + dy)
            buffer.blit(tail.sprite, at: origin.x, origin.y) { character in
                PixelArt.coatColor(character, palette: palette, species: species)
            }
        }

        drawLegs(&buffer, far: false, body: body, rig: rig, frame: frame, palette: palette)

        if let head = rig.heads[frame.head] {
            var grid = head.map { Array($0) }
            SpriteOps.applyEyes(frame.eyes, to: &grid)
            applyMouth(frame.mouth, species: species, to: &grid)
            let origin = PixelPoint(x: body.head.x + frame.headDX, y: body.head.y + frame.headDY + dy)
            buffer.blit(grid.map { String($0) }, at: origin.x, origin.y) { character in
                switch character {
                case "T": palette.accent
                default: PixelArt.coatColor(character, palette: palette, species: species, blushing: frame.blush, mouthOpen: frame.mouth == .open)
                }
            }
        }

        drawAccessory(&buffer, accessory, neck: body.neck, dy: dy, palette: palette)

        if let bowl = frame.bowl {
            drawBowl(&buffer, bowl, species: species)
        }
        for particle in frame.particles {
            if let sprite = ParticleSprites.sprite(for: particle.kind, frame: particle.frame) {
                buffer.blit(sprite, at: particle.x, particle.y) { PixelArt.propColors[$0] }
            }
        }

        if !facingRight {
            buffer.flipHorizontally()
        }
        return buffer
    }

    // MARK: Parts

    private static func drawLegs(_ buffer: inout PixelBuffer, far: Bool, body: BodyPose, rig: PetRig, frame: PetFrame, palette: CoatPalette) {
        let pairs: [(LegAnchor?, LegPose)] = far
            ? [(body.legs.farFront, frame.legs.farFront), (body.legs.farBack, frame.legs.farBack)]
            : [(body.legs.nearFront, frame.legs.nearFront), (body.legs.nearBack, frame.legs.nearBack)]
        for (anchor, pose) in pairs {
            guard let anchor else { continue }
            drawLeg(&buffer, x: anchor.x + pose.dx, top: anchor.top + frame.dy, lift: pose.lift, width: rig.legWidth, far: far, palette: palette)
        }
    }

    /// A leg from the body's bottom edge to the ground: outline both sides, fur inside, a light
    /// paw on the bottom row, and an outline underneath. Lifting shortens it.
    private static func drawLeg(_ buffer: inout PixelBuffer, x: Int, top: Int, lift: Int, width: Int, far: Bool, palette: CoatPalette) {
        let bottom = ground - lift
        guard bottom >= top else { return }
        let fur = far ? palette.shadow : palette.base
        let paw = far ? palette.shadow : palette.highlight
        for y in top...bottom {
            buffer.set(x - 1, y, palette.outline)
            buffer.set(x + width, y, palette.outline)
            for column in x..<(x + width) {
                buffer.set(column, y, y == bottom && bottom - top >= 1 ? paw : fur)
            }
        }
        for column in (x - 1)...(x + width) {
            buffer.set(column, bottom + 1, palette.outline)
        }
    }

    private static func applyMouth(_ mouth: MouthStyle, species: PetSpecies, to grid: inout [[Character]]) {
        for y in grid.indices {
            for x in grid[y].indices where grid[y][x] == "o" {
                switch mouth {
                case .closed:
                    break
                case .open:
                    grid[y][x] = "#"
                    if grid.indices.contains(y + 1), "bl#".contains(grid[y + 1][x]) {
                        grid[y + 1][x] = "T"
                    }
                case .tongue:
                    grid[y][x] = "#"
                    if grid.indices.contains(y + 1) { grid[y + 1][x] = "T" }
                    if grid.indices.contains(y + 2), grid[y + 2].indices.contains(x), grid[y + 2][x] == "." { grid[y + 2][x] = "T" }
                }
            }
        }
    }

    private static func drawAccessory(_ buffer: inout PixelBuffer, _ accessory: PetAccessory, neck: NeckBand, dy: Int, palette: CoatPalette) {
        let y = neck.y + dy
        let fur: Set<RGBA> = [palette.base, palette.shadow, palette.highlight, palette.marking]
        func paint(_ x: Int, _ y: Int, _ color: RGBA, onlyOverFur: Bool = true) {
            if !onlyOverFur || (buffer.get(x, y).map { fur.contains($0) } ?? false) {
                buffer.set(x, y, color)
            }
        }
        let band = neck.x..<(neck.x + neck.width)
        switch accessory {
        case .none:
            break
        case .collar:
            for x in band { paint(x, y, PixelArt.collar) }
        case .bandana:
            for x in band { paint(x, y, PixelArt.bandana) }
            let middle = neck.x + neck.width / 2
            paint(middle, y + 1, PixelArt.bandana)
            paint(middle - 1, y + 1, PixelArt.bandana)
            paint(middle, y + 2, PixelArt.bandana)
        case .bow:
            for x in band { paint(x, y, PixelArt.collar) }
            let knot = neck.x + neck.width - 1
            paint(knot, y, PixelArt.bow, onlyOverFur: false)
            paint(knot - 1, y - 1, PixelArt.bow, onlyOverFur: false)
            paint(knot + 1, y - 1, PixelArt.bow, onlyOverFur: false)
            paint(knot - 1, y + 1, PixelArt.bow, onlyOverFur: false)
            paint(knot + 1, y + 1, PixelArt.bow, onlyOverFur: false)
        }
    }

    private static func drawBowl(_ buffer: inout PixelBuffer, _ bowl: BowlPlacement, species: PetSpecies) {
        buffer.blit(PetSprites.bowl, at: bowl.x, bowl.y) { PixelArt.propColors[$0] }
        let food = species == .cat ? PetSprites.fish : PetSprites.bone
        switch bowl.food {
        case .full:
            buffer.blit(food, at: bowl.x + 1, bowl.y - 3) { PixelArt.propColors[$0] }
        case .half:
            let right = food.map { String($0.suffix(4)) }
            buffer.blit(right, at: bowl.x + 4, bowl.y - 3) { PixelArt.propColors[$0] }
        case .empty:
            break
        }
    }
}

/// Two- or three-frame particles, 3×3 to 5×5 pixels.
enum ParticleSprites {
    static func sprite(for kind: ParticleKind, frame: Int) -> Sprite? {
        let frames: [Sprite]
        switch kind {
        case .heart: frames = hearts
        case .zzz: frames = zzz
        case .sparkle: frames = sparkles
        case .dust: frames = dust
        }
        guard !frames.isEmpty else { return nil }
        return frames[frame % frames.count]
    }

    static let hearts: [Sprite] = [
        ["h.h", "hhh", ".h."],
        [".h.h.", "hhhhh", ".hhh.", "..h.."],
        [".h.h.", "hwhhh", "hhhhh", ".hhh.", "..h.."],
    ]

    static let zzz: [Sprite] = [
        ["zzz", ".z.", "zzz"],
        ["zzzz", "..z.", ".z..", "zzzz"],
        ["zzz..", ".z...", "zzz.z", "...z.", "..zzz"],
    ]

    static let sparkles: [Sprite] = [
        [".x.", "xxx", ".x."],
        ["..x..", "..x..", "xxxxx", "..x..", "..x.."],
    ]

    static let dust: [Sprite] = [
        [".s.", "sss"],
        [".sss.", "sssss", ".s.s."],
        ["s...s", ".s.s."],
    ]
}
