import Foundation

enum MouthStyle: String, Hashable {
    case closed, open, tongue
}

struct LegPose: Hashable {
    var dx = 0
    /// Rows the foot is lifted off the ground.
    var lift = 0
}

struct LegPoses: Hashable {
    var nearFront = LegPose()
    var farFront = LegPose()
    var nearBack = LegPose()
    var farBack = LegPose()

    static let standing = LegPoses()
}

enum ParticleKind: String, Hashable {
    case heart, zzz, sparkle, dust
}

struct ParticlePlacement: Hashable {
    var kind: ParticleKind
    var frame: Int
    var x: Int
    var y: Int
}

enum FoodAmount: String, Hashable {
    case full, half, empty
}

struct BowlPlacement: Hashable {
    var x: Int
    var y: Int
    var food: FoodAmount
}

/// One drawn frame: which parts go where. Every number is a whole source pixel.
struct PetFrame: Hashable {
    var posture: Posture = .stand
    /// Whole-pet vertical offset. Feet stay on the ground, so legs shorten or lengthen to match.
    var dy = 0
    var headDX = 0
    var headDY = 0
    var head: HeadVariant = .side
    var eyes: EyeStyle = .open
    var mouth: MouthStyle = .closed
    var blush = false
    var tail: TailPose = .neutral
    var legs: LegPoses = .standing
    var bowl: BowlPlacement?
    var particles: [ParticlePlacement] = []

    var cacheKey: String {
        "\(posture)/\(dy)/\(headDX)/\(headDY)/\(head)/\(eyes)/\(mouth)/\(blush)/\(tail)/\(legs.hashValue)/\(bowl?.hashValue ?? 0)/\(particles.hashValue)"
    }
}

/// Every animation on the sheet. Frame counts and rates follow the spec; the walk and run strides
/// match the distance the stage moves the pet per frame so paws stay planted.
enum PetAnimation: String, Hashable, CaseIterable {
    case idle, sitIdle, walk, run, turn, sitDown, standUp, stretch, lieDown, sleep, groom, eat, pounce, hop, startled, look, content, embarrassed

    var fps: Double {
        switch self {
        case .idle: 4
        case .sitIdle: 2
        case .walk: 8
        case .run: 12
        case .turn: 6
        case .sitDown, .standUp, .lieDown: 6
        case .stretch: 6
        case .sleep: 2
        case .groom: 6
        case .eat: 6
        case .pounce: 8
        case .hop: 8
        case .startled: 8
        case .look: 1
        case .content: 4
        case .embarrassed: 3
        }
    }

    var loops: Bool {
        switch self {
        case .idle, .sitIdle, .walk, .run, .sleep: true
        default: false
        }
    }

    /// Source pixels the pet travels per frame while this animation plays.
    var stride: Int {
        switch self {
        case .walk: 1
        case .run: 2
        default: 0
        }
    }

    func frames(for species: PetSpecies) -> [PetFrame] {
        switch self {
        case .idle: return idleFrames(species)
        case .sitIdle: return sitIdleFrames(species)
        case .walk: return walkFrames(species)
        case .run: return runFrames(species)
        case .turn: return turnFrames(species)
        case .sitDown: return sitDownFrames(species)
        case .standUp: return sitDownFrames(species).reversed()
        case .stretch: return stretchFrames(species)
        case .lieDown: return lieDownFrames(species)
        case .sleep: return sleepFrames(species)
        case .groom: return groomFrames(species)
        case .eat: return eatFrames(species)
        case .pounce: return pounceFrames(species)
        case .hop: return hopFrames(species)
        case .startled: return startledFrames(species)
        case .look: return [PetFrame(head: .front, tail: species == .cat ? .up : .neutral)]
        case .content: return contentFrames(species)
        case .embarrassed: return embarrassedFrames(species)
        }
    }

    // MARK: Sheets

    private func restingTail(_ species: PetSpecies) -> TailPose { species == .cat ? .neutral : .neutral }
    private func happyTail(_ species: PetSpecies) -> TailPose { .up }

    private func idleFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(tail: .neutral),
            PetFrame(tail: .swish),
            PetFrame(dy: -1, tail: .swish),
            PetFrame(head: .twitch, tail: .neutral),
        ]
    }

    private func sitIdleFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(posture: .sit, tail: .low),
            PetFrame(posture: .sit, tail: .curl),
        ]
    }

    /// Diagonal gait: near-front with far-back, far-front with near-back, offset by half a cycle.
    private func gait(stance: [Int], swingLift: [Int]) -> [LegPoses] {
        let count = stance.count
        return (0..<count).map { index in
            let a = LegPose(dx: stance[index], lift: swingLift[index])
            let b = LegPose(dx: stance[(index + count / 2) % count], lift: swingLift[(index + count / 2) % count])
            return LegPoses(nearFront: a, farFront: b, nearBack: b, farBack: a)
        }
    }

    private func walkFrames(_ species: PetSpecies) -> [PetFrame] {
        let legs = gait(stance: [2, 1, 0, -1, 0, 2], swingLift: [0, 0, 0, 0, 2, 1])
        let bob = [0, -1, 0, 0, -1, 0]
        let tails: [TailPose] = species == .cat ? [.up, .up, .up, .up, .up, .up] : [.up, .up, .neutral, .neutral, .up, .up]
        return (0..<6).map { index in
            PetFrame(dy: bob[index], headDY: index % 3 == 1 ? 0 : 0, tail: tails[index], legs: legs[index])
        }
    }

    private func runFrames(_ species: PetSpecies) -> [PetFrame] {
        let legs = gait(stance: [3, 1, -1, -3, -1, 2], swingLift: [0, 0, 0, 0, 3, 2])
        let bob = species == .dog ? [0, -1, -2, -1, 0, 0] : [0, -1, -1, 0, 0, 0]
        return (0..<6).map { index in
            PetFrame(dy: bob[index], mouth: species == .dog ? .tongue : .closed, tail: .up, legs: legs[index])
        }
    }

    private func turnFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(head: .front, tail: .low, legs: LegPoses(nearFront: LegPose(dx: -1), farFront: LegPose(dx: 1), nearBack: LegPose(dx: 1), farBack: LegPose(dx: -1))),
            PetFrame(head: .front, tail: .low),
        ]
    }

    private func sitDownFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(dy: 1, tail: .low, legs: LegPoses(nearFront: LegPose(), farFront: LegPose(), nearBack: LegPose(dx: 1, lift: 1), farBack: LegPose(dx: 1, lift: 1))),
            PetFrame(posture: .sit, dy: 1, tail: .low),
            PetFrame(posture: .sit, tail: .low),
        ]
    }

    private func stretchFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(dy: 1, eyes: .half, tail: .low),
            PetFrame(posture: .stretch, eyes: .half, tail: .up),
            PetFrame(posture: .stretch, eyes: .closed, mouth: .open, tail: .up),
            PetFrame(posture: .stretch, eyes: .closed, mouth: .open, tail: .up),
            PetFrame(eyes: .half, tail: .neutral),
        ]
    }

    private func lieDownFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(posture: .sit, dy: 1, eyes: .half, tail: .low),
            PetFrame(posture: .lie, headDY: -1, eyes: .half, tail: .curl),
            PetFrame(posture: .lie, eyes: .closed, tail: .curl),
        ]
    }

    private func sleepFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(posture: .lie, eyes: .closed, tail: .curl, particles: [ParticlePlacement(kind: .zzz, frame: 0, x: 19, y: 6)]),
            PetFrame(posture: .lie, headDY: -1, eyes: .closed, tail: .curl, particles: [ParticlePlacement(kind: .zzz, frame: 1, x: 19, y: 3)]),
        ]
    }

    private func groomFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(posture: .sit, headDX: -1, headDY: 1, eyes: .half, tail: .low),
            PetFrame(posture: .sit, headDX: -2, headDY: 2, eyes: .closed, mouth: .tongue, tail: .low),
            PetFrame(posture: .sit, headDX: -1, headDY: 1, eyes: .closed, mouth: .tongue, tail: .swish),
            PetFrame(posture: .sit, eyes: .half, tail: .swish, particles: [ParticlePlacement(kind: .sparkle, frame: 1, x: 3, y: 3)]),
        ]
    }

    private func eatFrames(_ species: PetSpecies) -> [PetFrame] {
        let bowlX = 15
        return [
            PetFrame(headDY: 3, eyes: .open, tail: .neutral, bowl: BowlPlacement(x: bowlX, y: 19, food: .full)),
            PetFrame(headDY: 4, eyes: .closed, mouth: .open, tail: .neutral, bowl: BowlPlacement(x: bowlX, y: 19, food: .full)),
            PetFrame(headDY: 4, eyes: .closed, tail: .neutral, bowl: BowlPlacement(x: bowlX, y: 19, food: .half)),
            PetFrame(headDY: 2, eyes: .happy, blush: true, tail: .up, bowl: BowlPlacement(x: bowlX, y: 19, food: .empty)),
        ]
    }

    private func pounceFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(dy: 2, eyes: .open, tail: .low),
            PetFrame(dy: -3, tail: .up, legs: LegPoses(nearFront: LegPose(dx: 3, lift: 2), farFront: LegPose(dx: 2, lift: 2), nearBack: LegPose(dx: -2, lift: 3), farBack: LegPose(dx: -1, lift: 3))),
            PetFrame(dy: 1, tail: .up, particles: [ParticlePlacement(kind: .dust, frame: 0, x: 3, y: 19)]),
            PetFrame(eyes: .happy, tail: .up, particles: [ParticlePlacement(kind: .dust, frame: 1, x: 2, y: 18)]),
        ]
    }

    private func hopFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(dy: 1, eyes: .happy, mouth: species == .dog ? .tongue : .closed, tail: .up),
            PetFrame(dy: -3, eyes: .happy, mouth: species == .dog ? .tongue : .closed, blush: true, tail: .up, legs: LegPoses(nearFront: LegPose(lift: 3), farFront: LegPose(lift: 3), nearBack: LegPose(lift: 3), farBack: LegPose(lift: 3)), particles: [ParticlePlacement(kind: .heart, frame: 0, x: 19, y: 2)]),
            PetFrame(eyes: .happy, blush: true, tail: .up, particles: [ParticlePlacement(kind: .heart, frame: 1, x: 18, y: 0)]),
        ]
    }

    /// A still, happy reaction for Reduce Motion: no hop, just hearts.
    private func contentFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(eyes: .happy, blush: true, tail: .up, particles: [ParticlePlacement(kind: .heart, frame: 0, x: 19, y: 3)]),
            PetFrame(eyes: .happy, blush: true, tail: .up, particles: [ParticlePlacement(kind: .heart, frame: 1, x: 18, y: 1)]),
            PetFrame(eyes: .happy, blush: true, tail: .up, particles: [ParticlePlacement(kind: .heart, frame: 2, x: 17, y: 0)]),
        ]
    }

    /// Missed the pounce: sit, look at the floor, blush.
    private func embarrassedFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(posture: .sit, headDY: 1, eyes: .half, blush: true, tail: .low),
            PetFrame(posture: .sit, headDX: -1, headDY: 1, eyes: .half, blush: true, tail: .low),
        ]
    }

    private func startledFrames(_ species: PetSpecies) -> [PetFrame] {
        [
            PetFrame(dy: -1, eyes: .startled, tail: .up),
            PetFrame(eyes: .startled, tail: .up),
        ]
    }
}
