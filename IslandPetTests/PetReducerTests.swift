import XCTest
@testable import IslandPet

final class PetReducerTests: XCTestCase {
    private let adopted = Date(timeIntervalSince1970: 1_700_000_000)

    private func makePet(species: PetSpecies = .cat, needs: Needs = .fresh) -> PetState {
        PetState(adoptedAt: adopted, species: species, coat: .honey, name: "Mochi", needs: needs)
    }

    private func hours(_ value: Double) -> Date {
        adopted.addingTimeInterval(value * 3600)
    }

    // MARK: Time-based needs

    func testNeedsDecayLinearlyWithElapsedTime() {
        let pet = PetReducer.reconcile(makePet(), now: hours(10))
        XCTAssertEqual(pet.needs.fullness, 90 - 40, accuracy: 0.001)
        XCTAssertEqual(pet.needs.energy, 90 - 30, accuracy: 0.001)
        XCTAssertEqual(pet.needs.cleanliness, 95 - 20, accuracy: 0.001)
        XCTAssertEqual(pet.needs.mood, 85 - 20, accuracy: 0.001)
        XCTAssertEqual(pet.lastReconciledAt, hours(10))
    }

    func testReconcilingTwiceInStepsMatchesOneStep() {
        let stepped = PetReducer.reconcile(PetReducer.reconcile(makePet(), now: hours(3)), now: hours(8))
        let once = PetReducer.reconcile(makePet(), now: hours(8))
        XCTAssertEqual(stepped.needs, once.needs)
    }

    func testMoodDropsFasterWhenAnotherNeedIsLow() {
        let hungry = makePet(needs: Needs(fullness: 10, energy: 90, cleanliness: 90, mood: 80))
        let pet = PetReducer.reconcile(hungry, now: hours(5))
        XCTAssertEqual(pet.needs.mood, 80 - 10 - 10, accuracy: 0.001)
    }

    func testLongOfflineGapIsGentle() {
        let week = PetReducer.reconcile(makePet(), now: adopted.addingTimeInterval(7 * 86_400))
        for kind in NeedKind.allCases {
            XCTAssertGreaterThanOrEqual(week.needs[kind], GameBalance.offlineFloor, "\(kind) fell below the offline floor")
            XCTAssertLessThanOrEqual(week.needs[kind], GameBalance.needMax)
        }
        let year = PetReducer.reconcile(makePet(), now: adopted.addingTimeInterval(365 * 86_400))
        XCTAssertEqual(year.needs, week.needs, "gaps beyond the cap should reconcile the same as the cap")
    }

    func testNeedsNeverGoNegative() {
        let low = makePet(needs: Needs(fullness: 5, energy: 4, cleanliness: 3, mood: 2))
        let pet = PetReducer.reconcile(low, now: hours(6))
        XCTAssertEqual(pet.needs.fullness, 0)
        XCTAssertEqual(pet.needs.energy, 0)
        XCTAssertEqual(pet.needs.cleanliness, 0)
        XCTAssertEqual(pet.needs.mood, 0)
    }

    func testClockMovingBackwardsKeepsNeedsAndClampsTimestamps() {
        var pet = PetReducer.reconcile(makePet(), now: hours(5))
        pet.care.fed = hours(5)
        pet.sleepingUntil = hours(5.3)
        let earlier = hours(2)
        let rewound = PetReducer.reconcile(pet, now: earlier)
        XCTAssertEqual(rewound.needs, pet.needs)
        XCTAssertEqual(rewound.lastReconciledAt, earlier)
        XCTAssertEqual(rewound.care.fed, earlier)
        XCTAssertLessThanOrEqual(rewound.sleepingUntil ?? .distantFuture, earlier.addingTimeInterval(GameBalance.napDuration))
        let (_, outcome) = PetReducer.apply(.feed, to: rewound, now: earlier.addingTimeInterval(GameBalance.effects[.feed]!.cooldown + 1))
        XCTAssertFalse(outcome.diminished, "cooldowns should run from the corrected timestamp")
    }

    // MARK: Actions

    func testFeedRestoresFullnessAndEarnsBond() {
        let start = makePet(needs: Needs(fullness: 40, energy: 80, cleanliness: 80, mood: 80))
        let (pet, outcome) = PetReducer.apply(.feed, to: start, now: hours(1))
        XCTAssertEqual(pet.needs.fullness, 40 - 4 + 35, accuracy: 0.001)
        XCTAssertEqual(pet.bond, 4)
        XCTAssertEqual(pet.care.fed, hours(1))
        XCTAssertFalse(outcome.diminished)
        XCTAssertEqual(outcome.action, .feed)
    }

    func testRepeatingAnActionInsideCooldownIsDiminished() {
        let start = makePet(needs: Needs(fullness: 20, energy: 80, cleanliness: 80, mood: 80))
        let (fed, _) = PetReducer.apply(.feed, to: start, now: hours(1))
        let (again, outcome) = PetReducer.apply(.feed, to: fed, now: hours(1).addingTimeInterval(60))
        XCTAssertTrue(outcome.diminished)
        XCTAssertEqual(again.bond, fed.bond)
        XCTAssertEqual(outcome.needChanges[.fullness] ?? 0, 35 * GameBalance.diminishedMultiplier, accuracy: 0.1)
    }

    func testNeedsAreCappedAtOneHundred() {
        let (pet, _) = PetReducer.apply(.feed, to: makePet(), now: hours(0.1))
        XCTAssertEqual(pet.needs.fullness, GameBalance.needMax)
    }

    func testPlayCostsEnergyAndHelpsLessWhenTired() {
        let tired = makePet(needs: Needs(fullness: 80, energy: 10, cleanliness: 80, mood: 50))
        let (pet, outcome) = PetReducer.apply(.play, to: tired, now: hours(0.01))
        XCTAssertEqual(outcome.needChanges[.mood] ?? 0, 12.5, accuracy: 0.1)
        XCTAssertLessThan(pet.needs.energy, 10)
    }

    func testGroomRestoresCleanliness() {
        let scruffy = makePet(needs: Needs(fullness: 80, energy: 80, cleanliness: 20, mood: 80))
        let (pet, _) = PetReducer.apply(.groom, to: scruffy, now: hours(0.01))
        XCTAssertGreaterThan(pet.needs.cleanliness, 55)
    }

    func testNapRestoresEnergyOverTimeAndEnds() {
        let sleepy = makePet(needs: Needs(fullness: 80, energy: 50, cleanliness: 80, mood: 80))
        let (napping, _) = PetReducer.apply(.nap, to: sleepy, now: hours(1))
        XCTAssertTrue(napping.isSleeping(at: hours(1).addingTimeInterval(60)))
        let rested = PetReducer.reconcile(napping, now: hours(1).addingTimeInterval(GameBalance.napDuration))
        XCTAssertGreaterThan(rested.needs.energy, napping.needs.energy)
        XCTAssertNil(rested.sleepingUntil)
    }

    func testAnyCareWakesASleepingPet() {
        let (napping, _) = PetReducer.apply(.nap, to: makePet(), now: hours(1))
        let (woken, _) = PetReducer.apply(.pet, to: napping, now: hours(1).addingTimeInterval(30))
        XCTAssertNil(woken.sleepingUntil)
    }

    // MARK: Growth and bond

    func testGrowthMilestones() {
        let pet = makePet()
        XCTAssertEqual(pet.growthStage(at: adopted), .baby)
        XCTAssertEqual(pet.growthStage(at: adopted.addingTimeInterval(GameBalance.youngAgeDays * 86_400 - 1)), .baby)
        XCTAssertEqual(pet.growthStage(at: adopted.addingTimeInterval(GameBalance.youngAgeDays * 86_400)), .young)
        XCTAssertEqual(pet.growthStage(at: adopted.addingTimeInterval(GameBalance.adultAgeDays * 86_400)), .adult)
        XCTAssertEqual(pet.growthStage(at: adopted.addingTimeInterval(-86_400)), .baby, "a clock before adoption still reads as a baby")
    }

    func testBondLevelsProgress() {
        XCTAssertEqual(PetReducer.bondLevel(0).level, 1)
        XCTAssertEqual(PetReducer.bondLevel(0).progress, 0, accuracy: 0.001)
        XCTAssertEqual(PetReducer.bondLevel(30).level, 2)
        XCTAssertEqual(PetReducer.bondLevel(15).progress, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(PetReducer.bondLevel(2_000).level, PetReducer.bondLevel(440).level)
    }

    // MARK: Derived state

    func testSuggestionPointsAtTheLowestNeed() {
        let hungry = makePet(needs: Needs(fullness: 30, energy: 80, cleanliness: 80, mood: 80))
        let suggestion = PetReducer.suggestion(for: hungry, now: adopted)
        XCTAssertEqual(suggestion.action, .feed)
        XCTAssertEqual(suggestion.urgency, .low)
        let starving = makePet(needs: Needs(fullness: 5, energy: 80, cleanliness: 80, mood: 80))
        XCTAssertEqual(PetReducer.suggestion(for: starving, now: adopted).urgency, .urgent)
        XCTAssertEqual(PetReducer.suggestion(for: makePet(), now: adopted).urgency, .fine)
    }

    func testIslandStateFollowsRecentActivityThenSettles() {
        let (fed, _) = PetReducer.apply(.feed, to: makePet(), now: hours(1))
        let eating = PetReducer.islandState(for: fed, now: hours(1).addingTimeInterval(10))
        XCTAssertEqual(eating.state, .eating)
        XCTAssertNotNil(eating.timed)
        let later = PetReducer.islandState(for: fed, now: hours(1).addingTimeInterval(GameBalance.eatingShown + 1))
        XCTAssertEqual(later.state, .idle)
        let hungry = makePet(needs: Needs(fullness: 10, energy: 80, cleanliness: 80, mood: 80))
        XCTAssertEqual(PetReducer.islandState(for: hungry, now: adopted).state, .attention)
    }

    func testHoursUntilNeedLow() {
        let pet = makePet(needs: Needs(fullness: 51, energy: 100, cleanliness: 100, mood: 100))
        XCTAssertEqual(PetReducer.hoursUntilNeedLow(pet, now: adopted) ?? -1, 4, accuracy: 0.001)
        let low = makePet(needs: Needs(fullness: 20, energy: 100, cleanliness: 100, mood: 100))
        XCTAssertNil(PetReducer.hoursUntilNeedLow(low, now: adopted))
    }
}
