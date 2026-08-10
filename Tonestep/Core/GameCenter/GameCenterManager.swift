import GameKit
import SwiftUI

final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var playerName = ""

    // Leaderboard IDs — create these in App Store Connect
    static let speedRoundLeaderboard = "eariq.speedround.weekly"
    static let dailyChallengeLeaderboard = "eariq.dailychallenge.alltime"
    static let streakLeaderboard = "eariq.streak.alltime"

    private override init() { super.init() }

    func authenticate(presentingViewController: UIViewController? = nil) {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let vc = viewController, let presenter = presentingViewController {
                    presenter.present(vc, animated: true)
                } else if player.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.playerName = player.displayName
                } else {
                    self?.isAuthenticated = false
                }
            }
        }
    }

    func submitScore(_ score: Int, leaderboardID: String) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID])
        }
    }

    func reportAchievement(id: String, percent: Double = 100) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        Task { try? await GKAchievement.report([achievement]) }
    }
}

// MARK: - Game Center View

struct GameCenterLeaderboardView: UIViewControllerRepresentable {
    let leaderboardID: String

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(leaderboardID: leaderboardID,
                                            playerScope: .global,
                                            timeScope: .week)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
