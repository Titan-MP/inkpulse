import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Rewarded ads (the tasteful kind: only for revive + bonus shells)

@MainActor
final class AdsService: ObservableObject {
    @Published var adsRemoved = false
    @Published private(set) var rewardedReady = false

    /// Test ad unit from Google. Replace with your real unit before release.
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    #if canImport(GoogleMobileAds)
    private var rewardedAd: GADRewardedAd?
    #endif

    init() {
        #if canImport(GoogleMobileAds)
        Task { await loadRewarded() }
        #endif
    }

    func loadRewarded() async {
        #if canImport(GoogleMobileAds)
        do {
            rewardedAd = try await GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: GADRequest())
            rewardedAd?.fullScreenContentDelegate = self
            rewardedReady = true
        } catch {
            rewardedReady = false
        }
        #else
        rewardedReady = false
        #endif
    }

    /// Shows a rewarded ad. Returns true if the user earned the reward.
    func showRewarded() async -> Bool {
        #if canImport(GoogleMobileAds)
        guard let ad = rewardedAd, let vc = topViewController() else { return false }
        rewardedReady = false
        return await withCheckedContinuation { continuation in
            self.pendingContinuation = continuation
            self.continuationResumed = false
            ad.present(fromRootViewController: vc) { [weak self] in
                self?.resumeRewardContinuation(true)
            }
        }
        #else
        return false
        #endif
    }

    #if canImport(GoogleMobileAds)
    private var pendingContinuation: CheckedContinuation<Bool, Never>?
    private var continuationResumed = false

    private func resumeRewardContinuation(_ value: Bool) {
        guard !continuationResumed else { return }
        continuationResumed = true
        pendingContinuation?.resume(returning: value)
        pendingContinuation = nil
    }
    #endif

    func adDidDismiss() {
        #if canImport(GoogleMobileAds)
        resumeRewardContinuation(false)
        #endif
        Task { await loadRewarded() }
    }
}

#if canImport(GoogleMobileAds)
extension AdsService: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenContent) {
        Task { @MainActor in self.adDidDismiss() }
    }
}
#endif
