import SwiftUI
import SpriteKit

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var state: GameState
    @EnvironmentObject var gameCenter: GameCenterService

    var body: some View {
        ZStack {
            switch state.screen {
            case .menu: MenuView()
            case .game(let daily): GameContainer(daily: daily)
            case .shop: ShopView()
            case .howTo: HowToView()
            }
        }
        .onChange(of: state.showGameOver) { _, shown in
            if shown, let summary = state.runSummary {
                gameCenter.submit(score: summary.score, daily: summary.daily)
            }
        }
    }
}

// MARK: - Menu

struct MenuView: View {
    @EnvironmentObject var state: GameState
    @EnvironmentObject var gameCenter: GameCenterService

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0A3A52"), Color(hex: "#06283D")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                OctopusMark(skin: state.equippedSkin, size: 120)
                Text("INKPULSE")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("a blue-ringed octopus arcade")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#8CE8FF"))
                if state.best > 0 {
                    Text("Best reef: \(state.best)")
                        .foregroundColor(.white.opacity(0.7))
                }
                if state.dailyStreak > 1 {
                    Text("\(state.dailyStreak)-day streak")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#FFD94D"))
                }
                Spacer()
                MenuButton(title: "Dive In", color: Color(hex: "#28C8FF")) {
                    Haptics.tap(); state.startRun(daily: false)
                }
                MenuButton(title: "Daily Reef", color: Color(hex: "#4CAF6D")) {
                    Haptics.tap(); state.startRun(daily: true)
                }
                HStack(spacing: 12) {
                    MenuButton(title: "Skins & Shop", color: Color(hex: "#7A6FF0"), small: true) {
                        state.screen = .shop
                    }
                    MenuButton(title: "How to Play", color: Color(hex: "#3E6B8A"), small: true) {
                        state.screen = .howTo
                    }
                }
                Button("Leaderboards") { gameCenter.showLeaderboard() }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
                Text("🐙 \(state.shells) shells")
                    .foregroundColor(Color(hex: "#FFD94D"))
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct MenuButton: View {
    let title: String
    let color: Color
    var small = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(small ? .title3 : .title2)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, small ? 12 : 16)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(18)
                .shadow(color: color.opacity(0.4), radius: 12, y: 4)
        }
    }
}

/// SwiftUI octopus mark for menus and shop.
struct OctopusMark: View {
    let skin: Skin
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: skin.mantleHex))
                .frame(width: size, height: size)
            ForEach(0..<8) { i in
                Circle()
                    .fill(Color(hex: skin.ringsHex))
                    .frame(width: size * 0.13, height: size * 0.13)
                    .offset(x: cos(CGFloat(i) / 8 * 2 * .pi) * size * 0.26,
                            y: sin(CGFloat(i) / 8 * 2 * .pi) * size * 0.26)
                    .shadow(color: Color(hex: skin.ringsHex), radius: 6)
            }
            HStack(spacing: size * 0.12) {
                Circle().fill(.white).frame(width: size * 0.2, height: size * 0.2)
                    .overlay(Circle().fill(.black).frame(width: size * 0.09, height: size * 0.09))
                Circle().fill(.white).frame(width: size * 0.2, height: size * 0.2)
                    .overlay(Circle().fill(.black).frame(width: size * 0.09, height: size * 0.09))
            }
            .offset(y: -size * 0.08)
        }
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

// MARK: - Game container + HUD

struct GameContainer: View {
    @EnvironmentObject var state: GameState
    @EnvironmentObject var ads: AdsService
    @EnvironmentObject var store: StoreService
    let daily: Bool
    @State private var scene: GameScene?

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                    .onAppear { scene.isPaused = false }
            } else {
                Color(hex: "#06283D").ignoresSafeArea()
            }

            // HUD
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(state.score)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        if state.combo > 1 {
                            Text("COMBO x\(state.combo)")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#FFD94D"))
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(i < state.hearts ? Color(hex: "#28C8FF") : Color.white.opacity(0.2))
                                .frame(width: 18, height: 18)
                                .shadow(color: Color(hex: "#28C8FF"), radius: i < state.hearts ? 6 : 0)
                        }
                    }
                    Button(state.isPaused ? "▶" : "❚❚") {
                        state.isPaused.toggle()
                        scene?.isPaused = state.isPaused
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.leading, 8)
                }
                .padding()

                Spacer()

                // Ink meter
                VStack(spacing: 6) {
                    HStack {
                        Text("INK").font(.caption).bold().foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(state.dashReady ? "DASH READY — double-tap!" : "\(Int(state.ink))%")
                            .font(.caption).bold()
                            .foregroundColor(state.dashReady ? Color(hex: "#FFD94D") : .white.opacity(0.7))
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#28C8FF"))
                                .frame(width: g.size.width * CGFloat(state.ink / 100))
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, 20)

                // Pulse button
                HStack {
                    Spacer()
                    Button {
                        scene?.doPulse()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(state.pulseReady ? Color(hex: "#28C8FF") : Color.gray.opacity(0.4))
                                .frame(width: 92, height: 92)
                                .shadow(color: Color(hex: "#28C8FF"), radius: state.pulseReady ? 14 : 0)
                            Text("PULSE")
                                .bold().foregroundColor(.white)
                        }
                    }
                    .padding(24)
                }
            }

            if daily {
                VStack {
                    Text("DAILY REEF")
                        .font(.caption).bold()
                        .foregroundColor(Color(hex: "#FFD94D"))
                        .padding(.top, 54)
                    Spacer()
                }
            }
        }
        .onAppear {
            let s = GameScene(size: UIScreen.main.bounds.size, daily: daily, state: state)
            s.scaleMode = .resizeFill
            scene = s
        }
        .sheet(isPresented: $state.showGameOver) {
            if let summary = state.runSummary {
                GameOverView(summary: summary, scene: scene)
            }
        }
    }
}

// MARK: - Game over

struct GameOverView: View {
    @EnvironmentObject var state: GameState
    @EnvironmentObject var ads: AdsService
    @EnvironmentObject var store: StoreService
    let summary: RunSummary
    let scene: GameScene?
    @State private var working = false
    @State private var doubled = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0A3A52"), Color(hex: "#06283D")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text(summary.isNewBest ? "NEW BEST!" : "Run Over")
                    .font(.largeTitle).bold()
                    .foregroundColor(summary.isNewBest ? Color(hex: "#FFD94D") : .white)
                Text("\(summary.score)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Best: \(summary.best)  •  Perfect stuns: \(summary.perfectStuns)")
                    .foregroundColor(.white.opacity(0.7))
                Text("+\(doubled ? summary.shellsEarned * 2 : summary.shellsEarned) shells")
                    .font(.title2).bold()
                    .foregroundColor(Color(hex: "#FFD94D"))

                if state.canReviveThisRun && !ads.adsRemoved && ads.rewardedReady {
                    Button {
                        Task {
                            working = true
                            let earned = await ads.showRewarded()
                            working = false
                            if earned { scene?.revive() }
                        }
                    } label: {
                        Text(working ? "Loading…" : "📺 Revive & keep swimming")
                            .bold().frame(maxWidth: .infinity).padding()
                            .background(Color(hex: "#4CAF6D")).foregroundColor(.white).cornerRadius(14)
                    }
                    .disabled(working)
                }

                if !ads.adsRemoved && ads.rewardedReady && !doubled {
                    Button {
                        Task {
                            working = true
                            let earned = await ads.showRewarded()
                            working = false
                            if earned {
                                doubled = true
                                state.addShells(summary.shellsEarned)
                            }
                        }
                    } label: {
                        Text(working ? "Loading…" : "📺 Double my shells")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.white.opacity(0.15)).foregroundColor(.white).cornerRadius(14)
                    }
                    .disabled(working)
                }

                Button("Swim Again") {
                    state.startRun(daily: summary.daily)
                }
                .bold().frame(maxWidth: .infinity).padding()
                .background(Color(hex: "#28C8FF")).foregroundColor(.white).cornerRadius(14)

                Button("Back to Surface") { state.screen = .menu }
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(28)
        }
    }
}

// MARK: - How to play

struct HowToView: View {
    @EnvironmentObject var state: GameState

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0A3A52"), Color(hex: "#06283D")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How to Play").font(.largeTitle).bold().foregroundColor(.white)
                    tip("🖐 Drag", "Steer your octopus through the reef.")
                    tip("⚡ Tap", "Flash your venom rings to stun predators. Time it just before they strike for a PERFECT stun and combo multiplier.")
                    tip("🦐 Eat shrimp", "Fill your ink meter. At 50%+, double-tap to ink-dash: brief invincibility that stuns everything in your path.")
                    tip("😱 Near miss", "Thread past a predator for a CLOSE! bonus.")
                    tip("📅 Daily Reef", "Everyone gets the same reef each day. Climb the leaderboard.")
                    tip("🐚 Shells", "Earn shells every run. Spend them on new color-morph skins.")
                    Spacer()
                    Button("Got it") { state.screen = .menu }
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(Color(hex: "#28C8FF")).foregroundColor(.white).cornerRadius(14)
                }
                .padding(28)
            }
        }
    }

    func tip(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundColor(Color(hex: "#8CE8FF"))
            Text(body).foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - Shop

struct ShopView: View {
    @EnvironmentObject var state: GameState
    @EnvironmentObject var store: StoreService
    @State private var buying = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0A3A52"), Color(hex: "#06283D")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("Skins & Shop").font(.largeTitle).bold().foregroundColor(.white)
                        Spacer()
                        Text("🐚 \(state.shells)").font(.title3).bold().foregroundColor(Color(hex: "#FFD94D"))
                    }

                    Text("OCTOPUS SKINS").font(.headline).foregroundColor(.white.opacity(0.6))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(Skin.all) { skin in
                            SkinCard(skin: skin)
                        }
                    }

                    Text("UPGRADES").font(.headline).foregroundColor(.white.opacity(0.6))
                    if store.removeAds {
                        row("Remove Ads", "Active — enjoy the clean reef", nil)
                    } else if let p = store.product(for: StoreIDs.removeAds) {
                        row("Remove Ads", "No rewarded ads, ever", p)
                    }
                    ForEach([StoreIDs.shellsSmall, StoreIDs.shellsMedium, StoreIDs.shellsLarge], id: \.self) { id in
                        if let p = store.product(for: id),
                           let amount = StoreIDs.shellAmounts[id] {
                            row("🐚 \(amount) shells", "For skins and revives", p)
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .foregroundColor(.white.opacity(0.7))

                    Button("Back") { state.screen = .menu }
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(Color.white.opacity(0.15)).foregroundColor(.white).cornerRadius(14)
                }
                .padding(24)
            }
        }
        .task { if store.products.isEmpty { await store.load() } }
    }

    func row(_ title: String, _ subtitle: String, _ product: Product?) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).bold().foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            if let product {
                Button(product.displayPrice) {
                    Task {
                        buying = true
                        let ok = await store.purchase(product)
                        buying = false
                        if ok { await handlePurchase(product.id) }
                    }
                }
                .bold().padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(hex: "#4CAF6D")).foregroundColor(.white).cornerRadius(12)
                .disabled(buying)
            }
        }
        .padding()
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
    }

    func handlePurchase(_ id: String) async {
        if let amount = StoreIDs.shellAmounts[id] {
            state.addShells(amount)
        } else if let skinID = StoreIDs.skinForProduct[id] {
            state.ownSkin(skinID)
            state.equipSkin(skinID)
        }
    }
}

struct SkinCard: View {
    @EnvironmentObject var state: GameState
    @EnvironmentObject var store: StoreService
    let skin: Skin
    @State private var buying = false

    var body: some View {
        VStack(spacing: 10) {
            OctopusMark(skin: skin, size: 84)
            Text(skin.name).bold().foregroundColor(.white)
            if state.equippedSkinID == skin.id {
                Text("Equipped").font(.caption).foregroundColor(Color(hex: "#4CAF6D"))
            } else if state.ownedSkinIDs.contains(skin.id) {
                Button("Equip") { state.equipSkin(skin.id) }
                    .font(.caption).bold().padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "#28C8FF")).foregroundColor(.white).cornerRadius(10)
            } else if let price = skin.shellPrice {
                Button("🐚 \(price)") {
                    if state.spendShells(price) { state.ownSkin(skin.id); state.equipSkin(skin.id) }
                    else { Haptics.notify(.warning) }
                }
                .font(.caption).bold().padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#FFD94D")).foregroundColor(.black).cornerRadius(10)
            } else if let pid = skin.productID, let product = store.product(for: pid) {
                Button(product.displayPrice) {
                    Task {
                        buying = true
                        let ok = await store.purchase(product)
                        buying = false
                        if ok { state.ownSkin(skin.id); state.equipSkin(skin.id) }
                    }
                }
                .font(.caption).bold().padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#7A6FF0")).foregroundColor(.white).cornerRadius(10)
                .disabled(buying)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
    }
}
