import Foundation

struct PixelPoint: Hashable {
    var x: Int
    var y: Int
}

enum Posture: String, Hashable, CaseIterable {
    case stand, sit, lie, stretch
}

enum HeadVariant: String, Hashable {
    case side, front, twitch
}

enum TailPose: String, Hashable {
    case up, neutral, low, curl, swish
}

struct LegAnchor: Hashable {
    var x: Int
    var top: Int
}

struct LegAnchors: Hashable {
    var nearFront: LegAnchor?
    var farFront: LegAnchor?
    var nearBack: LegAnchor?
    var farBack: LegAnchor?
}

struct NeckBand: Hashable {
    var x: Int
    var y: Int
    var width: Int
}

/// A body drawn for one posture, with where everything else attaches to it.
struct BodyPose {
    var sprite: Sprite
    var origin: PixelPoint
    var head: PixelPoint
    var neck: NeckBand
    var legs: LegAnchors
    var tail: PixelPoint
}

struct TailPart {
    var sprite: Sprite
    /// The cell that lands on the body's tail anchor and joins the two.
    var join: PixelPoint
}

/// All hand-drawn parts for one species at one growth stage, on a 24×24 canvas facing right.
/// Feet rest on row 21; light comes from the upper left (`h` highlight, `d` shadow).
struct PetRig {
    var legWidth: Int
    var bodies: [Posture: BodyPose]
    var heads: [HeadVariant: Sprite]
    var tails: [TailPose: TailPart]

    static func rig(for species: PetSpecies, stage: GrowthStage) -> PetRig {
        switch (species, stage) {
        case (.cat, .baby): PetRigs.catBaby
        case (.cat, .young): PetRigs.catYoung
        case (.cat, .adult): PetRigs.catAdult
        case (.dog, .baby): PetRigs.dogBaby
        case (.dog, .young): PetRigs.dogYoung
        case (.dog, .adult): PetRigs.dogAdult
        }
    }
}

// Letters: # outline · b base · d shadow · h highlight · l light (muzzle, belly, paws) · s stripe
// marking (tabby only) · q patch marking (patches only) · e eye · n nose · p pink ear · o mouth ·
// k cheek. Legs are not drawn in these parts; the composer draws them from stride values.
enum PetRigs {
    // MARK: - Cat

    private static let catHeadAdult: Sprite = [
        ".#.....#.",
        "#p#...#p#",
        "#hh###qq#",
        "#hsbsbqq#",
        "#beebeeb#",
        "#beebeeb#",
        "#kllnllk#",
        ".#lloll#.",
    ]

    private static let catHeadAdultFront: Sprite = [
        ".#.....#.",
        "#p#...#p#",
        "#hh###qq#",
        "#hsbsbqq#",
        "#eebbbee#",
        "#eebbbee#",
        "#kllnllk#",
        ".#lloll#.",
    ]

    private static let catHeadAdultTwitch: Sprite = [
        ".#....#..",
        "#p#..#p#.",
        "#hh###qq#",
        "#hsbsbqq#",
        "#beebeeb#",
        "#beebeeb#",
        "#kllnllk#",
        ".#lloll#.",
    ]

    private static let catHeadBaby: Sprite = [
        ".#......#.",
        "#p#....#p#",
        "#hh####qq#",
        "#hsbsbbqq#",
        "#bbbbbbbb#",
        "#beebbeeb#",
        "#beebbeeb#",
        "#klllnllk#",
        ".#llloll#.",
    ]

    private static let catHeadBabyFront: Sprite = [
        ".#......#.",
        "#p#....#p#",
        "#hh####qq#",
        "#hsbsbbqq#",
        "#bbbbbbbb#",
        "#eebbbbee#",
        "#eebbbbee#",
        "#klllnllk#",
        ".#llloll#.",
    ]

    private static let catTailsLong: [TailPose: TailPart] = [
        .up: TailPart(sprite: [
            ".##",
            "#b#",
            "#b#",
            "#b#",
            "#b#",
            "#b#",
            "#b#",
            "#bb",
            ".#.",
        ], join: PixelPoint(x: 2, y: 7)),
        .neutral: TailPart(sprite: [
            ".##....",
            "#b#####",
            "#bbbbbb",
            ".######",
        ], join: PixelPoint(x: 6, y: 2)),
        .swish: TailPart(sprite: [
            ".##....",
            ".#b#...",
            ".#b####",
            "#bbbbbb",
            ".######",
        ], join: PixelPoint(x: 6, y: 3)),
        .low: TailPart(sprite: [
            "..#b",
            ".#b#",
            ".#b#",
            "#b#.",
            "#b#.",
            "#b#.",
            "#b#.",
            ".#..",
        ], join: PixelPoint(x: 3, y: 0)),
        .curl: TailPart(sprite: [
            "..#b",
            ".#b#",
            "#bb#",
            ".##.",
        ], join: PixelPoint(x: 3, y: 0)),
    ]

    private static let catTailsShort: [TailPose: TailPart] = [
        .up: TailPart(sprite: [
            ".##",
            "#b#",
            "#b#",
            "#b#",
            "#bb",
            ".#.",
        ], join: PixelPoint(x: 2, y: 4)),
        .neutral: TailPart(sprite: [
            ".##..",
            "#b###",
            "#bbbb",
            ".####",
        ], join: PixelPoint(x: 4, y: 2)),
        .swish: TailPart(sprite: [
            "..##.",
            ".#b##",
            "#bbbb",
            ".####",
        ], join: PixelPoint(x: 4, y: 2)),
        .low: TailPart(sprite: [
            "..#b",
            ".#b#",
            "#b#.",
            "#b#.",
            ".#..",
        ], join: PixelPoint(x: 3, y: 0)),
        .curl: TailPart(sprite: [
            "..#b",
            ".#b#",
            "#bb#",
            ".##.",
        ], join: PixelPoint(x: 3, y: 0)),
    ]

    static let catAdult = PetRig(
        legWidth: 1,
        bodies: [
            .stand: BodyPose(
                sprite: [
                    ".##########.",
                    "#hhsbsbsqqd#",
                    "#hbsbsbbqqd#",
                    "#bbbbbbbbdd#",
                    "#bllllbbbdd#",
                    ".##########.",
                ],
                origin: PixelPoint(x: 6, y: 12), head: PixelPoint(x: 13, y: 5),
                neck: NeckBand(x: 13, y: 13, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 15, top: 17), farFront: LegAnchor(x: 13, top: 17), nearBack: LegAnchor(x: 8, top: 17), farBack: LegAnchor(x: 10, top: 17)),
                tail: PixelPoint(x: 6, y: 13)
            ),
            .sit: BodyPose(
                sprite: [
                    "....########",
                    "..##hhsbsbd#",
                    ".#hhbsbsqqd#",
                    "#hbbbbbbqqd#",
                    "#bbbbbbbbbd#",
                    "#bbbbbblllb#",
                    "#dbbbbblllb#",
                    ".##########.",
                ],
                origin: PixelPoint(x: 6, y: 10), head: PixelPoint(x: 13, y: 3),
                neck: NeckBand(x: 12, y: 11, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 15, top: 17), farFront: LegAnchor(x: 13, top: 17), nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 6, y: 16)
            ),
            .lie: BodyPose(
                sprite: [
                    ".##########.",
                    "#hhsbsbsqqd#",
                    "#hbsbsbbqqd#",
                    "#bbbbbbbbdd#",
                    "#bllbbbbbdd#",
                    ".##########.",
                ],
                origin: PixelPoint(x: 6, y: 16), head: PixelPoint(x: 13, y: 9),
                neck: NeckBand(x: 13, y: 17, width: 4),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 6, y: 19)
            ),
            .stretch: BodyPose(
                sprite: [
                    ".###.........",
                    "#hbb#........",
                    "#hsbb##......",
                    "#bsbsbb###...",
                    "#bbbbbbbbb##.",
                    ".#dbbbbbqqbb#",
                    "..##dbbbbbbd#",
                    "....########.",
                ],
                origin: PixelPoint(x: 5, y: 12), head: PixelPoint(x: 14, y: 12),
                neck: NeckBand(x: 12, y: 16, width: 2),
                legs: LegAnchors(nearFront: LegAnchor(x: 20, top: 19), farFront: LegAnchor(x: 18, top: 19), nearBack: LegAnchor(x: 8, top: 18), farBack: LegAnchor(x: 10, top: 18)),
                tail: PixelPoint(x: 5, y: 13)
            ),
        ],
        heads: [.side: catHeadAdult, .front: catHeadAdultFront, .twitch: catHeadAdultTwitch],
        tails: catTailsLong
    )

    static let catYoung = PetRig(
        legWidth: 1,
        bodies: [
            .stand: BodyPose(
                sprite: [
                    ".########.",
                    "#hsbsbsqd#",
                    "#hbsbbqqd#",
                    "#bllbbbdd#",
                    ".########.",
                ],
                origin: PixelPoint(x: 7, y: 14), head: PixelPoint(x: 12, y: 7),
                neck: NeckBand(x: 12, y: 15, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 14, top: 18), farFront: LegAnchor(x: 12, top: 18), nearBack: LegAnchor(x: 9, top: 18), farBack: LegAnchor(x: 11, top: 18)),
                tail: PixelPoint(x: 7, y: 15)
            ),
            .sit: BodyPose(
                sprite: [
                    "...#######",
                    ".##hsbsqd#",
                    "#hbbsbqqd#",
                    "#bbbbbbbd#",
                    "#bbbblllb#",
                    "#dbbblllb#",
                    ".########.",
                ],
                origin: PixelPoint(x: 7, y: 12), head: PixelPoint(x: 12, y: 5),
                neck: NeckBand(x: 11, y: 13, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 14, top: 18), farFront: LegAnchor(x: 12, top: 18), nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 7, y: 17)
            ),
            .lie: BodyPose(
                sprite: [
                    ".########.",
                    "#hsbsbsqd#",
                    "#hbsbbqqd#",
                    "#bllbbbdd#",
                    ".########.",
                ],
                origin: PixelPoint(x: 7, y: 17), head: PixelPoint(x: 12, y: 10),
                neck: NeckBand(x: 12, y: 18, width: 4),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 7, y: 19)
            ),
            .stretch: BodyPose(
                sprite: [
                    ".###.......",
                    "#hbb#......",
                    "#bsbb##....",
                    "#bbbbbb###.",
                    ".#dbbbbqqb#",
                    "..##dbbbbd#",
                    "....######.",
                ],
                origin: PixelPoint(x: 6, y: 14), head: PixelPoint(x: 13, y: 13),
                neck: NeckBand(x: 11, y: 17, width: 2),
                legs: LegAnchors(nearFront: LegAnchor(x: 19, top: 20), farFront: LegAnchor(x: 17, top: 20), nearBack: LegAnchor(x: 8, top: 19), farBack: LegAnchor(x: 10, top: 19)),
                tail: PixelPoint(x: 6, y: 15)
            ),
        ],
        heads: [.side: catHeadAdult, .front: catHeadAdultFront, .twitch: catHeadAdultTwitch],
        tails: catTailsLong
    )

    static let catBaby = PetRig(
        legWidth: 1,
        bodies: [
            .stand: BodyPose(
                sprite: [
                    ".######.",
                    "#hsbsqd#",
                    "#hbbqqd#",
                    "#bllbdd#",
                    ".######.",
                ],
                origin: PixelPoint(x: 8, y: 15), head: PixelPoint(x: 12, y: 7),
                neck: NeckBand(x: 12, y: 16, width: 3),
                legs: LegAnchors(nearFront: LegAnchor(x: 13, top: 19), farFront: LegAnchor(x: 11, top: 19), nearBack: LegAnchor(x: 9, top: 19), farBack: nil),
                tail: PixelPoint(x: 8, y: 16)
            ),
            .sit: BodyPose(
                sprite: [
                    "...#####",
                    ".##hsbd#",
                    "#hbbqqd#",
                    "#bbbbbd#",
                    "#bbllbb#",
                    ".######.",
                ],
                origin: PixelPoint(x: 8, y: 14), head: PixelPoint(x: 12, y: 6),
                neck: NeckBand(x: 11, y: 15, width: 3),
                legs: LegAnchors(nearFront: LegAnchor(x: 13, top: 19), farFront: LegAnchor(x: 11, top: 19), nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 8, y: 18)
            ),
            .lie: BodyPose(
                sprite: [
                    ".######.",
                    "#hsbsqd#",
                    "#bllbdd#",
                    ".######.",
                ],
                origin: PixelPoint(x: 8, y: 18), head: PixelPoint(x: 12, y: 10),
                neck: NeckBand(x: 12, y: 19, width: 3),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 8, y: 20)
            ),
            .stretch: BodyPose(
                sprite: [
                    ".##......",
                    "#hb##....",
                    "#bsbb###.",
                    ".#dbbqqb#",
                    "..######.",
                ],
                origin: PixelPoint(x: 7, y: 17), head: PixelPoint(x: 13, y: 13),
                neck: NeckBand(x: 11, y: 19, width: 2),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 7, y: 18)
            ),
        ],
        heads: [.side: catHeadBaby, .front: catHeadBabyFront, .twitch: catHeadBaby],
        tails: catTailsShort
    )

    // MARK: - Dog

    /// Floppy ears hang beside a narrower face; the muzzle is light with a dark nose.
    private static let dogHead: Sprite = [
        "...#######...",
        ".###hbbbq###.",
        "#dd#hbbbq#dd#",
        "#dd#eebee#dd#",
        "#dd#eebee#dd#",
        "#dd#bbbbb#dd#",
        ".###klnlk###.",
        "...#lloll#...",
        "....#####....",
    ]

    private static let dogHeadTwitch: Sprite = [
        "...#######...",
        "#dd#hbbbq#dd#",
        "#dd#hbbbq#dd#",
        "#dd#eebee#dd#",
        ".###eebee###.",
        "...#bbbbb#...",
        "...#klnlk#...",
        "...#lloll#...",
        "....#####....",
    ]

    private static let dogTailsLong: [TailPose: TailPart] = [
        .up: TailPart(sprite: [
            ".##",
            "#b#",
            "#b#",
            "#b#",
            "#b#",
            "#bb",
            ".#.",
        ], join: PixelPoint(x: 2, y: 5)),
        .neutral: TailPart(sprite: [
            ".##....",
            "#b#....",
            ".#b#...",
            "..#b#..",
            "...#bbb",
            "....##.",
        ], join: PixelPoint(x: 6, y: 4)),
        .swish: TailPart(sprite: [
            ".##",
            "#b#",
            "#b#",
            "#b#",
            "#b#",
            "#bb",
            ".#.",
        ], join: PixelPoint(x: 2, y: 5)),
        .low: TailPart(sprite: [
            "..#b",
            ".#b#",
            ".#b#",
            "#b#.",
            "#b#.",
            "#b#.",
            ".#..",
        ], join: PixelPoint(x: 3, y: 0)),
        .curl: TailPart(sprite: [
            "..#b",
            ".#b#",
            "#bb#",
            ".##.",
        ], join: PixelPoint(x: 3, y: 0)),
    ]

    private static let dogTailsShort: [TailPose: TailPart] = [
        .up: TailPart(sprite: [
            ".##",
            "#b#",
            "#b#",
            "#bb",
            ".#.",
        ], join: PixelPoint(x: 2, y: 3)),
        .neutral: TailPart(sprite: [
            ".##..",
            "#b#..",
            ".#b#.",
            "..#bb",
            "...#.",
        ], join: PixelPoint(x: 4, y: 3)),
        .swish: TailPart(sprite: [
            ".##",
            "#b#",
            "#b#",
            "#bb",
            ".#.",
        ], join: PixelPoint(x: 2, y: 3)),
        .low: TailPart(sprite: [
            "..#b",
            ".#b#",
            "#b#.",
            "#b#.",
            ".#..",
        ], join: PixelPoint(x: 3, y: 0)),
        .curl: TailPart(sprite: [
            "..#b",
            ".#b#",
            "#bb#",
            ".##.",
        ], join: PixelPoint(x: 3, y: 0)),
    ]

    static let dogAdult = PetRig(
        legWidth: 2,
        bodies: [
            .stand: BodyPose(
                sprite: [
                    ".###########.",
                    "#hhbbbbbbqqd#",
                    "#hbbbbbbbqqd#",
                    "#bbbbbbbbbbd#",
                    "#bbbbbbbbbdd#",
                    "#blllbbbbddd#",
                    ".###########.",
                ],
                origin: PixelPoint(x: 5, y: 11), head: PixelPoint(x: 11, y: 4),
                neck: NeckBand(x: 13, y: 13, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 14, top: 17), farFront: LegAnchor(x: 12, top: 17), nearBack: LegAnchor(x: 7, top: 17), farBack: LegAnchor(x: 9, top: 17)),
                tail: PixelPoint(x: 5, y: 13)
            ),
            .sit: BodyPose(
                sprite: [
                    "....#########",
                    "..##hhbbbqqd#",
                    ".#hhbbbbbqqd#",
                    "#hbbbbbbbbbd#",
                    "#bbbbbbbbbbd#",
                    "#bbbbbbblllb#",
                    "#bbbbbbblllb#",
                    "#dbbbbbblllb#",
                    ".###########.",
                ],
                origin: PixelPoint(x: 5, y: 9), head: PixelPoint(x: 11, y: 2),
                neck: NeckBand(x: 12, y: 11, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 14, top: 17), farFront: LegAnchor(x: 12, top: 17), nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 5, y: 15)
            ),
            .lie: BodyPose(
                sprite: [
                    ".###########.",
                    "#hhbbbbbbqqd#",
                    "#hbbbbbbbqqd#",
                    "#bbbbbbbbbdd#",
                    "#bllbbbbbddd#",
                    ".###########.",
                ],
                origin: PixelPoint(x: 5, y: 16), head: PixelPoint(x: 11, y: 9),
                neck: NeckBand(x: 13, y: 17, width: 4),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 5, y: 18)
            ),
            .stretch: BodyPose(
                sprite: [
                    ".###..........",
                    "#hbb#.........",
                    "#hbbb##.......",
                    "#bbbbbb###....",
                    "#bbbbbbbbb##..",
                    ".#dbbbbbbqqbb#",
                    "..##dbbbbbbbd#",
                    "....#########.",
                ],
                origin: PixelPoint(x: 4, y: 12), head: PixelPoint(x: 11, y: 12),
                neck: NeckBand(x: 11, y: 16, width: 2),
                legs: LegAnchors(nearFront: LegAnchor(x: 19, top: 20), farFront: LegAnchor(x: 17, top: 20), nearBack: LegAnchor(x: 7, top: 18), farBack: LegAnchor(x: 9, top: 18)),
                tail: PixelPoint(x: 4, y: 14)
            ),
        ],
        heads: [.side: dogHead, .front: dogHead, .twitch: dogHeadTwitch],
        tails: dogTailsLong
    )

    static let dogYoung = PetRig(
        legWidth: 2,
        bodies: [
            .stand: BodyPose(
                sprite: [
                    ".#########.",
                    "#hhbbbbqqd#",
                    "#hbbbbbqqd#",
                    "#bbbbbbbdd#",
                    "#blllbbddd#",
                    ".#########.",
                ],
                origin: PixelPoint(x: 6, y: 13), head: PixelPoint(x: 11, y: 6),
                neck: NeckBand(x: 12, y: 15, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 13, top: 18), farFront: LegAnchor(x: 11, top: 18), nearBack: LegAnchor(x: 7, top: 18), farBack: LegAnchor(x: 9, top: 18)),
                tail: PixelPoint(x: 6, y: 15)
            ),
            .sit: BodyPose(
                sprite: [
                    "...########",
                    ".##hbbbqqd#",
                    "#hbbbbbqqd#",
                    "#bbbbbbbbd#",
                    "#bbbbbbllb#",
                    "#dbbbbbllb#",
                    "#dbbbbbllb#",
                    ".#########.",
                ],
                origin: PixelPoint(x: 6, y: 11), head: PixelPoint(x: 11, y: 4),
                neck: NeckBand(x: 11, y: 13, width: 4),
                legs: LegAnchors(nearFront: LegAnchor(x: 13, top: 18), farFront: LegAnchor(x: 11, top: 18), nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 6, y: 16)
            ),
            .lie: BodyPose(
                sprite: [
                    ".#########.",
                    "#hhbbbbqqd#",
                    "#hbbbbbqqd#",
                    "#bllbbbddd#",
                    ".#########.",
                ],
                origin: PixelPoint(x: 6, y: 17), head: PixelPoint(x: 11, y: 10),
                neck: NeckBand(x: 12, y: 18, width: 4),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 6, y: 19)
            ),
            .stretch: BodyPose(
                sprite: [
                    ".###........",
                    "#hbb#.......",
                    "#bbbb##.....",
                    "#bbbbbb###..",
                    ".#dbbbbqqbb#",
                    "..##dbbbbbd#",
                    "....#######.",
                ],
                origin: PixelPoint(x: 5, y: 14), head: PixelPoint(x: 11, y: 12),
                neck: NeckBand(x: 11, y: 17, width: 2),
                legs: LegAnchors(nearFront: LegAnchor(x: 19, top: 20), farFront: LegAnchor(x: 17, top: 20), nearBack: LegAnchor(x: 7, top: 19), farBack: LegAnchor(x: 9, top: 19)),
                tail: PixelPoint(x: 5, y: 15)
            ),
        ],
        heads: [.side: dogHead, .front: dogHead, .twitch: dogHeadTwitch],
        tails: dogTailsLong
    )

    static let dogBaby = PetRig(
        legWidth: 2,
        bodies: [
            .stand: BodyPose(
                sprite: [
                    ".######.",
                    "#hbbqqd#",
                    "#bbbqqd#",
                    "#bllbdd#",
                    ".######.",
                ],
                origin: PixelPoint(x: 8, y: 15), head: PixelPoint(x: 10, y: 7),
                neck: NeckBand(x: 12, y: 16, width: 3),
                legs: LegAnchors(nearFront: LegAnchor(x: 13, top: 19), farFront: LegAnchor(x: 11, top: 19), nearBack: LegAnchor(x: 9, top: 19), farBack: nil),
                tail: PixelPoint(x: 8, y: 16)
            ),
            .sit: BodyPose(
                sprite: [
                    "...#####",
                    ".##hbqd#",
                    "#hbbqqd#",
                    "#bbbbbd#",
                    "#bbllbd#",
                    ".######.",
                ],
                origin: PixelPoint(x: 8, y: 14), head: PixelPoint(x: 10, y: 6),
                neck: NeckBand(x: 11, y: 15, width: 3),
                legs: LegAnchors(nearFront: LegAnchor(x: 13, top: 19), farFront: LegAnchor(x: 11, top: 19), nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 8, y: 18)
            ),
            .lie: BodyPose(
                sprite: [
                    ".######.",
                    "#hbbqqd#",
                    "#bllbdd#",
                    ".######.",
                ],
                origin: PixelPoint(x: 8, y: 18), head: PixelPoint(x: 10, y: 10),
                neck: NeckBand(x: 12, y: 19, width: 3),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 8, y: 20)
            ),
            .stretch: BodyPose(
                sprite: [
                    ".##......",
                    "#hb##....",
                    "#bbbb###.",
                    ".#dbbqqb#",
                    "..######.",
                ],
                origin: PixelPoint(x: 7, y: 17), head: PixelPoint(x: 11, y: 13),
                neck: NeckBand(x: 11, y: 19, width: 2),
                legs: LegAnchors(nearFront: nil, farFront: nil, nearBack: nil, farBack: nil),
                tail: PixelPoint(x: 7, y: 18)
            ),
        ],
        heads: [.side: dogHead, .front: dogHead, .twitch: dogHeadTwitch],
        tails: dogTailsShort
    )
}
