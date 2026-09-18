import Foundation
import GameKit
import UIKit

// MARK: - Game Center: leaderboards for the daily reef + all-time best

@MainActor
final class GameCenterService: ObservableObject {
    @Published private(set) var isAuthenticated = false

    static let leaderboardAllTime = "reef_best"
    static let leaderboardDaily = "reef_daily"

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            Task { @MainActor in
                if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                } else if let vc, let top = topViewController() {
                    top.present(vc, animated: true)
                }
                if error != nil { self?.isAuthenticated = false }
            }
        }
    }

    func submit(score: Int, daily: Bool) {
        guard isAuthenticated else { return }
        let id = daily ? Self.leaderboardDaily : Self.leaderboardAllTime
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id])
        }
    }

    func showLeaderboard() {
        let vc = GKGameCenterViewController(leaderboardID: Self.leaderboardAllTime, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = GameCenterDelegate.shared
        topViewController()?.present(vc, animated: true)
    }
}

private final class GameCenterDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDelegate()
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
