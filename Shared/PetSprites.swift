import Foundation

/// Hand-drawn 16×16 pet sprites and the small props that go with them.
enum PetSprites {
    static let size = 16

    // MARK: Cat

    static let catSit: Sprite = [
        "................",
        "....#.....#.....",
        "...#p#...#p#....",
        "...#bb###bb#.###",
        "...#bsbsbsq#.#b#",
        "...#eebbbee#.#b#",
        "...#eelllee#.#b#",
        "...#kllnllk#.#b#",
        "...#bllmllb#.#b#",
        "....#ccccc#..#b#",
        "....#bbbqq#..#b#",
        "....#blllbbbbb#.",
        "....#l###l#####.",
        "....###.###.....",
        "................",
        "................",
    ]

    /// Tail tip one pixel lower: alternating with `catSit` reads as a slow swish.
    static let catSitSwish: Sprite = [
        "................",
        "....#.....#.....",
        "...#p#...#p#....",
        "...#bb###bb#....",
        "...#bsbsbsq#.###",
        "...#eebbbee#.#b#",
        "...#eelllee#.#b#",
        "...#kllnllk#.#b#",
        "...#bllmllb#.#b#",
        "....#ccccc#..#b#",
        "....#bbbqq#..#b#",
        "....#blllbbbbb#.",
        "....#l###l#####.",
        "....###.###.....",
        "................",
        "................",
    ]

    static let catWalkA: Sprite = [
        "................",
        ".........#...#..",
        "........#p#.#p#.",
        ".###....#bb#qq#.",
        ".#b#....#bsbsq#.",
        ".#b#....#eebee#.",
        ".#b#....#eebee#.",
        ".#b#....#klnlk#.",
        ".#b######blmlb#.",
        ".#bbsbsbbbbbbb#.",
        "..#bbsbsbccccc#.",
        "...#bbbbbblllb#.",
        "...##b######b##.",
        "....#l#....#l#..",
        "....###....###..",
        "................",
    ]

    static let catWalkB: Sprite = [
        "................",
        ".........#...#..",
        "........#p#.#p#.",
        ".###....#bb#qq#.",
        ".#b#....#bsbsq#.",
        ".#b#....#eebee#.",
        ".#b#....#eebee#.",
        ".#b#....#klnlk#.",
        ".#b######blmlb#.",
        ".#bbsbsbbbbbbb#.",
        "..#bbsbsbccccc#.",
        "...#bbbbbblllb#.",
        "...###b####b###.",
        ".....#l#..#l#...",
        ".....###..###...",
        "................",
    ]

    static let catSleep: Sprite = [
        "................",
        "................",
        "................",
        "................",
        "........#...#...",
        ".......#p#.#p#..",
        ".......#bb#qq#..",
        "..#####bbbbbq#..",
        ".#bbbbbb##b##b#.",
        ".#bbbbbbbblnlb#.",
        ".#bbsbsbsbbbbb#.",
        ".#bbbbbbbbbbbb#.",
        ".#bbbbbbbbbbbb#.",
        ".##bbbbbbb#####.",
        "..########......",
        "................",
    ]

    // MARK: Dog

    static let dogSit: Sprite = [
        "................",
        "..###########...",
        "..#dqqbbbbbd#...",
        "..#dqeebeebd#...",
        "..#dbeebeebd#...",
        "..#dkbbbbbkd#...",
        "..##bllnllb##...",
        "...#bllmllb#....",
        "...#bbbtbbb#.##.",
        "....#ccccc#..#b#",
        "....#bbbbb#..#b#",
        "....#blllbbbbb#.",
        "....#l###l#####.",
        "....###.###.....",
        "................",
        "................",
    ]

    /// Tail one pixel higher: alternating with `dogSit` is a wag.
    static let dogSitWag: Sprite = [
        "................",
        "..###########...",
        "..#dqqbbbbbd#...",
        "..#dqeebeebd#...",
        "..#dbeebeebd#...",
        "..#dkbbbbbkd#...",
        "..##bllnllb##...",
        "...#bllmllb#.##.",
        "...#bbbtbbb#.#b#",
        "....#ccccc#..#b#",
        "....#bbbbb#..#b#",
        "....#blllbbbbb#.",
        "....#l###l#####.",
        "....###.###.....",
        "................",
        "................",
    ]

    static let dogWalkA: Sprite = [
        "................",
        "................",
        "........#######.",
        "........#dqbbd#.",
        "........#dqbbd#.",
        "........#dbbbd#.",
        ".##.....#eebee#.",
        ".#b#....#eebee#.",
        "..#b#...#klnlk#.",
        "...#b####blmlb#.",
        "...#bbbbbccccc#.",
        "...#bbbbbblllb#.",
        "...##b######b##.",
        "....#l#....#l#..",
        "....###....###..",
        "................",
    ]

    static let dogWalkB: Sprite = [
        "................",
        "................",
        "........#######.",
        "........#dqbbd#.",
        "........#dqbbd#.",
        "........#dbbbd#.",
        ".##.....#eebee#.",
        ".#b#....#eebee#.",
        "..#b#...#klnlk#.",
        "...#b####blmlb#.",
        "...#bbbbbccccc#.",
        "...#bbbbbblllb#.",
        "...###b####b###.",
        ".....#l#..#l#...",
        ".....###..###...",
        "................",
    ]

    static let dogSleep: Sprite = [
        "................",
        "................",
        "................",
        "................",
        ".......#######..",
        ".......#dqbbd#..",
        ".......#dqbbd#..",
        "..#####bdbbbd#..",
        ".#bbbbbb##b##b#.",
        ".#bbbbbbbblnlb#.",
        ".#bbbbbbbbbbbb#.",
        ".#bbbbbbbbbbbb#.",
        ".#bbbbbbbbbbbb#.",
        ".##bbbbbbb#####.",
        "..########......",
        "................",
    ]

    // MARK: Props (each uses its own letters, see `PropSprite.colors`)

    static let heart: Sprite = [
        ".hh.hh.",
        "hwhhhhh",
        "hhhhhhh",
        ".hhhhh.",
        "..hhh..",
        "...h...",
    ]

    static let heartSmall: Sprite = [
        "h.h",
        "hhh",
        ".h.",
    ]

    static let zBig: Sprite = [
        "zzzz",
        "..z.",
        ".z..",
        "zzzz",
    ]

    static let zSmall: Sprite = [
        "zzz",
        ".z.",
        "zzz",
    ]

    static let fish: Sprite = [
        "..fff.f",
        ".feffff",
        ".fffff.",
        "..fff.f",
    ]

    static let bone: Sprite = [
        "oo...oo",
        "ooooooo",
        "ooooooo",
        "oo...oo",
    ]

    static let yarn: Sprite = [
        ".yyyy.",
        "ygyygy",
        "yyggyy",
        "ygyygy",
        ".yyyy.",
    ]

    static let ball: Sprite = [
        ".aaa.",
        "awaaa",
        "aawaa",
        "aaawa",
        ".aaa.",
    ]

    static let sparkleBig: Sprite = [
        "..x..",
        "..x..",
        "xxxxx",
        "..x..",
        "..x..",
    ]

    static let sparkleSmall: Sprite = [
        ".x.",
        "xxx",
        ".x.",
    ]

    static let comb: Sprite = [
        ".kkkkkk.",
        "kqqqqqqk",
        "kqkqkqkq",
        ".k.k.k.k",
    ]

    static let bang: Sprite = [
        "!!",
        "!!",
        "!!",
        "..",
        "!!",
    ]

    static let bowl: Sprite = [
        "uuuuuuuuu",
        "vvvvvvvvv",
        ".uuuuuuu.",
    ]
}
