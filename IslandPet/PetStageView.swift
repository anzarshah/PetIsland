import SwiftUI

/// The pet at home: a 24-pixel-tall pixel stage, scaled to whole device pixels so nothing shimmers.
/// Tapping the pet pets it.
struct PetStageView: View {
    var pet: PetState
    var outcome: ActionOutcome?
    var now: Date
    var onPet: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animator: PetAnimator?
    @State private var stageWidthPx = 96

    private static let rows = PetSpriteComposer.canvas
    private static let groundRow = PetSpriteComposer.ground + 1

    var body: some View {
        let caption = PetReducer.caption(for: pet, now: now)
        Button(action: onPet) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [Pastel.butter, Pastel.peach.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                GeometryReader { geometry in
                    stage(in: geometry.size)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
            }
            .frame(height: 232)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pet.displayName), \(caption)")
        .accessibilityHint("Double tap to pet")
        .task(id: "\(pet.id)-\(pet.species.rawValue)") {
            let animator = PetAnimator(species: pet.species, personality: pet.personality, reduceMotion: reduceMotion)
            animator.sync(isSleeping: pet.isSleeping(at: now))
            self.animator = animator
            while !Task.isCancelled {
                if animator.stageWidth != stageWidthPx { animator.stageWidth = stageWidthPx }
                animator.advance(to: Date.now.timeIntervalSinceReferenceDate)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
        .onChange(of: outcome) { _, outcome in
            guard let outcome else { return }
            animator?.react(to: outcome.action)
        }
        .onChange(of: pet.isSleeping(at: now)) { _, sleeping in
            animator?.sync(isSleeping: sleeping)
        }
        .onChange(of: pet.personality) { _, personality in
            animator?.personality = personality
        }
        .onChange(of: reduceMotion) { _, reduce in
            animator?.reduceMotion = reduce
        }
    }

    /// Lays the sprite out on a pixel grid: `unit` points per source pixel, snapped to device pixels.
    @ViewBuilder
    private func stage(in size: CGSize) -> some View {
        let unit = max(1, floor(size.height * displayScale / CGFloat(Self.rows))) / displayScale
        let widthPx = max(Self.rows, Int(size.width / unit))
        let spriteSide = unit * CGFloat(Self.rows)
        let stageHeight = spriteSide
        let yOffset = (size.height - stageHeight) / 2
        ZStack(alignment: .topLeading) {
            // Ground line on the row under the feet.
            Rectangle()
                .fill(Pastel.ground)
                .frame(width: CGFloat(widthPx) * unit, height: unit)
                .offset(y: yOffset + CGFloat(Self.groundRow) * unit)

            if let animator {
                PixelImage(image: PixelArt.shadow)
                    .frame(width: unit * 12, height: unit * 2)
                    .offset(x: CGFloat(animator.pixelX + 6) * unit, y: yOffset + CGFloat(Self.groundRow) * unit)

                if let toy = animator.toy {
                    let image = PixelArt.prop(toy.prop)
                    PixelImage(image: image)
                        .frame(width: unit * CGFloat(image.width), height: unit * CGFloat(image.height))
                        .offset(x: CGFloat(toy.x) * unit, y: yOffset + CGFloat(Self.groundRow - image.height) * unit)
                }

                PixelImage(image: PetSpriteComposer.render(
                    species: pet.species, coat: pet.coat, accessory: pet.accessory, stage: pet.growthStage(at: now),
                    frame: animator.frame, facingRight: animator.facingRight
                ))
                .frame(width: spriteSide, height: spriteSide)
                .offset(x: CGFloat(animator.pixelX) * unit, y: yOffset)
            }
        }
        .onAppear { stageWidthPx = widthPx }
        .onChange(of: widthPx) { _, width in stageWidthPx = width }
    }
}

extension PixelArt {
    /// A soft 12×2 shadow under the pet.
    static let shadow: CGImage = {
        var buffer = PixelBuffer(width: 12, height: 2)
        var tone = RGBA(hex: 0x3B2E4A)
        tone.a = 46
        for x in 1..<11 { buffer.set(x, 0, tone) }
        for x in 3..<9 { buffer.set(x, 1, tone) }
        return buffer.cgImage()!
    }()
}
