import Foundation
import Observation

/// Drives the pet on the home stage: picks behaviours with weighted randomness, sequences them
/// through natural transitions, plays reactions to care, and keeps a fixed animation clock.
/// All positions are whole source pixels on a 24-pixel-tall stage.
@MainActor
@Observable
final class PetAnimator {
    static let spriteSize = PetSpriteComposer.canvas

    // Inputs
    let species: PetSpecies
    var personality: PetPersonality
    var reduceMotion = false
    /// Stage width in source pixels; set by the view once it knows its size.
    var stageWidth = 96 {
        didSet { x = min(x, Double(max(0, stageWidth - Self.spriteSize))) }
    }

    // Output for the view
    private(set) var frame: PetFrame
    private(set) var facingRight = true
    private(set) var pixelX = 0
    private(set) var toy: (x: Int, prop: PetProp)?
    private(set) var animation: PetAnimation = .idle

    // Clock
    private var x: Double
    private var startedAt: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var loopsRemaining = 1
    private var queue: [PetAnimation] = []
    private var chaseTarget: Int?
    private var missPounce = false
    private var nextBlinkAt: TimeInterval = 0
    private var blinkUntil: TimeInterval = 0
    private var wantsSleep = false
    private var isAsleep = false
    private var idleLoopsSinceAction = 0
    private var sleepStartedAt: TimeInterval = 0
    /// Ambient loops before the pet drowses off on its own.
    private let drowsyAfterLoops = 10
    /// How long a self-started doze lasts before the pet stirs.
    private let dozeLength: TimeInterval = 45

    init(species: PetSpecies, personality: PetPersonality, reduceMotion: Bool = false) {
        self.species = species
        self.personality = personality
        self.reduceMotion = reduceMotion
        x = 36
        frame = PetAnimation.idle.frames(for: species)[0]
        pixelX = 36
    }

    // MARK: Driving

    /// Advance the clock. Call about 30 times a second while the stage is visible.
    func advance(to time: TimeInterval) {
        if lastTime == 0 {
            lastTime = time
            startedAt = time
            scheduleBlink(after: time)
        }
        let dt = min(0.25, max(0, time - lastTime))
        lastTime = time

        move(dt: dt)

        let frames = animation.frames(for: species)
        let elapsed = time - startedAt
        var index = Int(elapsed * animation.fps)
        if index >= frames.count {
            if animation.loops && loopsRemaining > 1 {
                loopsRemaining -= 1
                startedAt += Double(frames.count) / animation.fps
                index = Int((time - startedAt) * animation.fps)
            } else if animation == .sleep && (wantsSleep || time - sleepStartedAt < dozeLength) {
                startedAt += Double(frames.count) / animation.fps
                index = Int((time - startedAt) * animation.fps)
            } else if animation == .sleep {
                wake()
                index = 0
            } else {
                finishCurrent()
                startNext(at: time)
                index = 0
            }
        }

        var shown = animation.frames(for: species)[min(index, animation.frames(for: species).count - 1)]
        shown = applyBlink(to: shown, at: time)
        if shown != frame { frame = shown }
        let snapped = Int(x.rounded())
        if snapped != pixelX { pixelX = snapped }
    }

    /// A tap on the pet: an immediate look, then a happy reaction.
    func tap() {
        idleLoopsSinceAction = 0
        if isAsleep {
            wake()
            return
        }
        startNow([.look, reduceMotion ? .content : .hop])
    }

    /// Care from the action buttons or the Live Activity.
    func react(to action: PetAction) {
        idleLoopsSinceAction = 0
        switch action {
        case .pet:
            tap()
        case .feed:
            if isAsleep { wake() }
            startNow([.eat, reduceMotion ? .content : .hop])
        case .groom:
            if isAsleep { wake() }
            startNow(groomSequence())
        case .play:
            if isAsleep { wake() }
            startPlay()
        case .nap:
            // The model decides whether the pet is actually napping; `sync` follows it.
            break
        }
    }

    /// Follow the saved pet's sleep state.
    func sync(isSleeping: Bool) {
        guard isSleeping != wantsSleep else { return }
        wantsSleep = isSleeping
        if isSleeping {
            if !isAsleep { startNow(sleepSequence()) }
        } else if isAsleep {
            wake()
        }
    }

    // MARK: Sequencing

    private func startNow(_ sequence: [PetAnimation]) {
        toy = nil
        chaseTarget = nil
        queue = Array(sequence.dropFirst())
        if let first = sequence.first {
            start(first, at: lastTime)
        }
    }

    private func start(_ next: PetAnimation, at time: TimeInterval) {
        animation = next
        startedAt = time
        loopsRemaining = loops(for: next)
        isAsleep = next == .sleep
        if isAsleep { sleepStartedAt = time }
        frame = next.frames(for: species)[0]
    }

    private func finishCurrent() {
        switch animation {
        case .turn:
            facingRight.toggle()
        case .pounce:
            if !missPounce { toy = nil }
        case .embarrassed:
            toy = nil
        case .idle, .sitIdle:
            idleLoopsSinceAction += 1
        default:
            break
        }
    }

    private func startNext(at time: TimeInterval) {
        if !queue.isEmpty {
            start(queue.removeFirst(), at: time)
            return
        }
        if wantsSleep && !isAsleep {
            startNow(sleepSequence())
            return
        }
        if idleLoopsSinceAction >= drowsyAfterLoops {
            idleLoopsSinceAction = 0
            startNow(sleepSequence())
            return
        }
        start(chooseBehaviour(), at: time)
    }

    private func wake() {
        wantsSleep = false
        isAsleep = false
        startNow([.startled, .stretch])
    }

    private func loops(for animation: PetAnimation) -> Int {
        switch animation {
        case .idle: return species == .cat ? Int.random(in: 2...4) : Int.random(in: 1...3)
        case .sitIdle: return Int.random(in: 2...3)
        case .walk: return Int.random(in: 2...4)
        case .run: return Int.random(in: 1...2)
        default: return 1
        }
    }

    // MARK: Behaviour choice

    private enum Behaviour: CaseIterable {
        case idle, walk, groom, run, sitLook, stretch
    }

    private func weights() -> [Behaviour: Double] {
        var weights: [Behaviour: Double] = [.idle: 40, .walk: 25, .groom: 10, .run: 10, .sitLook: 10, .stretch: 5]
        switch personality {
        case .curious:
            weights[.walk] = 30
            weights[.sitLook] = 15
            weights[.idle] = 30
        case .cozy:
            weights[.idle] = 45
            weights[.groom] = 15
            weights[.stretch] = 10
            weights[.run] = 4
        case .bouncy:
            weights[.run] = 20
            weights[.walk] = 28
            weights[.idle] = 30
            weights[.groom] = 6
        }
        if species == .dog {
            weights[.run, default: 0] += 5
            weights[.groom, default: 0] = max(2, (weights[.groom] ?? 0) - 5)
        }
        if reduceMotion {
            weights[.walk] = 0
            weights[.run] = 0
        }
        return weights
    }

    private func chooseBehaviour() -> PetAnimation {
        let table = weights()
        let total = table.values.reduce(0, +)
        var pick = Double.random(in: 0..<max(total, 0.001))
        var chosen: Behaviour = .idle
        for behaviour in Behaviour.allCases {
            let weight = table[behaviour] ?? 0
            if pick < weight {
                chosen = behaviour
                break
            }
            pick -= weight
        }

        switch chosen {
        case .idle:
            return .idle
        case .walk:
            return beginMoving(.walk)
        case .run:
            return beginMoving(.run)
        case .groom:
            queue = Array(groomSequence().dropFirst())
            return groomSequence()[0]
        case .sitLook:
            queue = [.sitIdle, .standUp, .look]
            return .sitDown
        case .stretch:
            return .stretch
        }
    }

    /// Faces away from the nearest edge (turning first if needed) and walks or runs.
    private func beginMoving(_ gait: PetAnimation) -> PetAnimation {
        let room = Double(max(0, stageWidth - Self.spriteSize))
        let wantsRight: Bool
        if room <= 0 {
            wantsRight = facingRight
        } else if x < room * 0.25 {
            wantsRight = true
        } else if x > room * 0.75 {
            wantsRight = false
        } else {
            wantsRight = Bool.random()
        }
        if wantsRight != facingRight {
            queue = [gait]
            return .turn
        }
        return gait
    }

    private func groomSequence() -> [PetAnimation] {
        [.sitDown, .groom, .groom, .standUp]
    }

    private func sleepSequence() -> [PetAnimation] {
        if animation == .sitIdle || animation == .sitDown {
            return [.lieDown, .sleep]
        }
        return [.stretch, .sitDown, .lieDown, .sleep]
    }

    private func startPlay() {
        guard !reduceMotion else {
            startNow([.look, .content])
            return
        }
        let room = max(0, stageWidth - Self.spriteSize)
        let target = x < Double(room) / 2 ? room - 4 : 4
        toy = (x: target + (target > Int(x) ? Self.spriteSize - 4 : -2), prop: species == .cat ? .yarn : .ball)
        chaseTarget = target
        missPounce = Double.random(in: 0..<1) < (species == .cat ? 0.2 : 0.3)
        let needsTurn = (target > Int(x)) != facingRight
        queue = [.run]
        if needsTurn {
            queue.insert(.turn, at: 0)
        }
        startNext(at: lastTime)
    }

    // MARK: Movement and blinking

    private func move(dt: TimeInterval) {
        guard animation.stride > 0, !reduceMotion else { return }
        let speed = Double(animation.stride) * animation.fps
        let room = Double(max(0, stageWidth - Self.spriteSize))
        x += (facingRight ? speed : -speed) * dt
        if let target = chaseTarget {
            let reached = facingRight ? x >= Double(target) : x <= Double(target)
            if reached {
                x = Double(target)
                chaseTarget = nil
                queue = missPounce ? [.pounce, .embarrassed] : [.pounce]
                startedAt = lastTime - 1_000 // force the current gait to finish on the next advance
            }
            return
        }
        if x <= 0 || x >= room {
            x = min(max(x, 0), room)
            if animation.loops {
                queue.insert(.turn, at: 0)
                startedAt = lastTime - 1_000
            }
        }
    }

    private func scheduleBlink(after time: TimeInterval) {
        nextBlinkAt = time + Double.random(in: 2...6)
    }

    private func applyBlink(to frame: PetFrame, at time: TimeInterval) -> PetFrame {
        guard frame.eyes == .open else { return frame }
        if time >= nextBlinkAt {
            blinkUntil = time + 0.12
            scheduleBlink(after: time)
        }
        guard time < blinkUntil else { return frame }
        var blinked = frame
        blinked.eyes = .closed
        return blinked
    }
}
