import SwiftUI

@main
struct BlueRingApp: App {
    @StateObject private var gameState = GameState()
    @StateObject private var store = StoreService()
    @StateObject private var ads = AdsService()
    @StateObject private var gameCenter = GameCenterService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameState)
                .environmentObject(store)
                .environmentObject(ads)
                .environmentObject(gameCenter)
                .task {
                    gameCenter.authenticate()
                    await store.load()
                    ads.adsRemoved = store.removeAds
                }
                .onChange(of: store.removeAds) { _, removed in
                    ads.adsRemoved = removed
                }
        }
    }
}
