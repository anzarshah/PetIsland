import CoreGraphics
import Foundation

enum EyeStyle {
    case open, half, closed, happy, startled
}

/// Grid-level edits shared by the compact sprites and the full-size frame composer.
enum SpriteOps {
    /// Rewrites each rectangular block of `e` cells for an eye style. Open eyes get a shine in
    /// the upper-left pixel; closed eyes become a dash on the bottom row; happy eyes a dash on
    /// the top row; half-closed eyes lose their top row; startled eyes grow one pixel taller.
    static func applyEyes(_ style: EyeStyle, to grid: inout [[Character]]) {
        var seen = Set<[Int]>()
        for y in grid.indices {
            for x in grid[y].indices where grid[y][x] == "e" && !seen.contains([x, y]) {
                var block = [(x: Int, y: Int)]()
                var stack = [(x: x, y: y)]
                while let cell = stack.popLast() {
                    guard grid.indices.contains(cell.y), grid[cell.y].indices.contains(cell.x),
                          grid[cell.y][cell.x] == "e", seen.insert([cell.x, cell.y]).inserted else { continue }
                    block.append(cell)
                    stack += [(cell.x + 1, cell.y), (cell.x - 1, cell.y), (cell.x, cell.y + 1), (cell.x, cell.y - 1)]
                }
                let top = block.map(\.y).min() ?? y
                let bottom = block.map(\.y).max() ?? y
                let left = block.map(\.x).min() ?? x
                for cell in block {
                    switch style {
                    case .open:
                        if bottom > top && cell.x == left && cell.y == top { grid[cell.y][cell.x] = "w" }
                    case .half:
                        grid[cell.y][cell.x] = cell.y == top && bottom > top ? "b" : "e"
                    case .closed:
                        grid[cell.y][cell.x] = cell.y == bottom ? "#" : "b"
                    case .happy:
                        grid[cell.y][cell.x] = cell.y == top ? "#" : "b"
                    case .startled:
                        if cell.y == top, grid.indices.contains(top - 1), grid[top - 1][cell.x] == "b" {
                            grid[top - 1][cell.x] = "e"
                        }
                    }
                }
            }
        }
    }

    /// Paints an accessory over the neck band (`c` cells) of a sprite grid.
    static func applyAccessory(_ accessory: PetAccessory, to grid: inout [[Character]]) {
        var band = [(x: Int, y: Int)]()
        for y in grid.indices {
            for x in grid[y].indices where grid[y][x] == "c" {
                band.append((x, y))
            }
        }
        guard let first = band.first else { return }
        let midX = (band.map(\.x).min()! + band.map(\.x).max()!) / 2
        switch accessory {
        case .none:
            for cell in band { grid[cell.y][cell.x] = "b" }
        case .collar:
            for cell in band { grid[cell.y][cell.x] = "C" }
        case .bandana:
            for cell in band { grid[cell.y][cell.x] = "B" }
            let below = first.y + 1
            if grid.indices.contains(below), grid[below].indices.contains(midX), "bl".contains(grid[below][midX]) {
                grid[below][midX] = "B"
            }
        case .bow:
            for cell in band { grid[cell.y][cell.x] = "b" }
            for dx in -1...1 where grid[first.y].indices.contains(midX + dx) {
                grid[first.y][midX + dx] = "W"
            }
            let above = first.y - 1
            if grid.indices.contains(above) {
                for dx in [-1, 1] where grid[above].indices.contains(midX + dx) && "b".contains(grid[above][midX + dx]) {
                    grid[above][midX + dx] = "W"
                }
            }
        }
    }

    static func accessoryColor(_ character: Character) -> RGBA? {
        switch character {
        case "C": PixelArt.collar
        case "B": PixelArt.bandana
        case "W": PixelArt.bow
        default: nil
        }
    }
}

/// The hand-drawn 16×16 sprites shown in the Dynamic Island, one per island state.
extension PixelArt {
    static let compactSize = 16

    static func compact(species: PetSpecies, coat: PetCoat, accessory: PetAccessory, state: IslandState) -> CGImage {
        cached("compact/\(species.rawValue)/\(coat.rawValue)/\(accessory.rawValue)/\(state.rawValue)") {
            let palette = coat.palette(for: species)
            let (sprite, eyes) = compactSprite(species: species, state: state)
            var grid = sprite.map { Array($0) }
            SpriteOps.applyEyes(eyes, to: &grid)
            SpriteOps.applyAccessory(accessory, to: &grid)
            var buffer = PixelBuffer(width: compactSize, height: compactSize)
            let blushing = state == .happy
            buffer.blit(grid.map { String($0) }, at: 0, 0) { character in
                SpriteOps.accessoryColor(character)
                    ?? coatColor(character, palette: palette, species: species, blushing: blushing, mouthOpen: state == .eating, tongue: species == .dog && state == .happy)
            }
            switch state {
            case .eating:
                buffer.blit(PetSprites.bowl, at: 3, 13) { propColors[$0] }
            case .attention:
                buffer.blit(PetSprites.bang, at: 12, 0) { propColors[$0] }
            default:
                break
            }
            return buffer
        }
    }

    private static func compactSprite(species: PetSpecies, state: IslandState) -> (Sprite, EyeStyle) {
        switch (species, state) {
        case (.cat, .sleeping): (PetSprites.catSleep, .closed)
        case (.dog, .sleeping): (PetSprites.dogSleep, .closed)
        case (.cat, .playing): (PetSprites.catWalkA, .open)
        case (.dog, .playing): (PetSprites.dogWalkA, .open)
        case (.cat, .happy): (PetSprites.catSitSwish, .happy)
        case (.dog, .happy): (PetSprites.dogSitWag, .happy)
        case (.cat, .attention): (PetSprites.catSit, .startled)
        case (.dog, .attention): (PetSprites.dogSit, .startled)
        case (.cat, _): (PetSprites.catSit, .open)
        case (.dog, _): (PetSprites.dogSit, .open)
        }
    }
}
