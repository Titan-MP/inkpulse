import SwiftUI

// MARK: - Skins (real blue-ringed octopus color morphs)

struct Skin: Identifiable, Equatable {
    let id: String
    let name: String
    let mantleHex: String
    let armsHex: String
    let ringsHex: String
    /// Shell price to unlock, or nil when it is an IAP-only skin.
    let shellPrice: Int?
    /// StoreKit product id, or nil when it is a shells-only skin.
    let productID: String?

    static let all: [Skin] = [
        Skin(id: "lagoon", name: "Lagoon", mantleHex: "#7A5C3E", armsHex: "#6B4F34", ringsHex: "#28C8FF", shellPrice: 0, productID: nil),
        Skin(id: "ember", name: "Ember Reef", mantleHex: "#8A3B2E", armsHex: "#74301F", ringsHex: "#FFB02E", shellPrice: 400, productID: nil),
        Skin(id: "abyss", name: "Abyss", mantleHex: "#2E2A5A", armsHex: "#26224C", ringsHex: "#B28CFF", shellPrice: 900, productID: nil),
        Skin(id: "kelp", name: "Kelp Ghost", mantleHex: "#3E6B4F", armsHex: "#355C43", ringsHex: "#8CFFB2", shellPrice: nil, productID: StoreIDs.skinPackKelp),
        Skin(id: "coral", name: "Coral Dawn", mantleHex: "#A34A68", armsHex: "#8C3E58", ringsHex: "#FF8CD1", shellPrice: nil, productID: StoreIDs.skinPackCoral),
    ]
}

// MARK: - Game state

enum Screen: Equatable {
    case menu
    case game(daily: Bool)
    case shop
    case howTo
}

struct RunSummary: Equatable {
    let score: Int
    let best: Int
    let isNewBest: Bool
    let shellsEarned: Int
    let perfectStuns: Int
    let daily: Bool
}

@MainActor
final class GameState: ObservableObject {
    @Published var screen: Screen = .menu
    @Published var score = 0
    @Published var hearts = 3
    @Published var ink: Double = 0
    @Published var combo = 0
    @Published var pulseReady = true
    @Published var dashReady = false
    @Published var isPaused = false
    @Published var shells: Int = 0
    @Published var ownedSkinIDs: Set<String> = ["lagoon"]
    @Published var equippedSkinID: String = "lagoon"
    @Published var runSummary: RunSummary?
    @Published var showGameOver = false
    @Published var canReviveThisRun = false
    @Published var dailyStreak = 0

    private let defaults = UserDefaults.standard

    var equippedSkin: Skin {
        Skin.all.first { $0.id == equippedSkinID } ?? Skin.all[0]
    }

    var best: Int {
        get { defaults.integer(forKey: "best") }
        set { defaults.set(newValue, forKey: "best") }
    }

    var dailyBest: Int {
        get { defaults.integer(forKey: "dailyBest_\(Self.todayKey)") }
        set { defaults.set(newValue, forKey: "dailyBest_\(Self.todayKey)") }
    }

    static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    init() {
        shells = defaults.integer(forKey: "shells")
        if let owned = defaults.array(forKey: "ownedSkins") as? [String] { ownedSkinIDs = Set(owned) }
        if let id = defaults.string(forKey: "equippedSkin") { equippedSkinID = id }
        dailyStreak = defaults.integer(forKey: "dailyStreak")
        rollDailyStreak()
    }

    // MARK: - Run flow

    func startRun(daily: Bool) {
        score = 0; hearts = 3; ink = 0; combo = 0
        pulseReady = true; dashReady = false; isPaused = false
        runSummary = nil; showGameOver = false
        canReviveThisRun = true
        screen = .game(daily: daily)
        if daily { markDailyPlayed() }
    }

    func endRun(score: Int, shellsEarned: Int, perfectStuns: Int, daily: Bool) {
        let isNewBest: Bool
        let bestScore: Int
        if daily {
            isNewBest = score > dailyBest
            if isNewBest { dailyBest = score }
            bestScore = dailyBest
        } else {
            isNewBest = score > best
            if isNewBest { best = score }
            bestScore = best
        }
        addShells(shellsEarned)
        runSummary = RunSummary(score: score, best: bestScore, isNewBest: isNewBest,
                                shellsEarned: shellsEarned, perfectStuns: perfectStuns, daily: daily)
        showGameOver = true
    }

    // MARK: - Shells & skins

    func addShells(_ n: Int) {
        shells += n
        defaults.set(shells, forKey: "shells")
    }

    @discardableResult
    func spendShells(_ n: Int) -> Bool {
        guard shells >= n else { return false }
        shells -= n
        defaults.set(shells, forKey: "shells")
        return true
    }

    func ownSkin(_ id: String) {
        ownedSkinIDs.insert(id)
        defaults.set(Array(ownedSkinIDs), forKey: "ownedSkins")
    }

    func equipSkin(_ id: String) {
        guard ownedSkinIDs.contains(id) else { return }
        equippedSkinID = id
        defaults.set(id, forKey: "equippedSkin")
    }

    // MARK: - Daily streak (ethical retention hook)

    private func rollDailyStreak() {
        let last = defaults.string(forKey: "lastDailyPlay") ?? ""
        let today = Self.todayKey
        guard last != today else { return }
        let cal = Calendar.current
        if let lastDate = Self.keyFormatter.date(from: last),
           let todayDate = Self.keyFormatter.date(from: today),
           cal.dateComponents([.day], from: lastDate, to: todayDate).day == 1 {
            dailyStreak += 1
            if dailyStreak % 7 == 0 { addShells(250) } // weekly streak bonus
        } else if last.isEmpty == false {
            dailyStreak = 0
        }
        defaults.set(dailyStreak, forKey: "dailyStreak")
    }

    private func markDailyPlayed() {
        defaults.set(Self.todayKey, forKey: "lastDailyPlay")
        if dailyStreak == 0 { dailyStreak = 1; defaults.set(1, forKey: "dailyStreak") }
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
