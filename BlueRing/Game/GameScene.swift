import SpriteKit

// MARK: - The reef: endless arcade survival

final class GameScene: SKScene {
    private let daily: Bool
    private let state: GameState
    private var rng: SeededRNG

    private let world = SKNode()
    private var player: OctopusNode!
    private var predators: [PredatorNode] = []
    private var prey: [PreyNode] = []

    // Run state
    private var elapsed: TimeInterval = 0
    private var scoreF: Double = 0
    private var comboTimer: TimeInterval = 0
    private var perfectStuns = 0
    private var isOver = false
    private var invulnTimer: TimeInterval = 0
    private var pulseCooldown: TimeInterval = 0
    private var dashTimer: TimeInterval = 0
    private var shake: CGFloat = 0
    private var timeScale: CGFloat = 1
    private var lastUpdate: TimeInterval = 0

    // Spawning
    private var spawnTimer: TimeInterval = 0.8
    private var preyTimer: TimeInterval = 0.4

    // Touch: drag to steer, tap to pulse, double-tap to ink-dash
    private var steerTouch: UITouch?
    private var steerTarget: CGPoint = .zero
    private var touchBeganAt: TimeInterval = 0
    private var touchBeganAtPoint: CGPoint = .zero
    private var touchMovedFar = false
    private var pendingTapAt: TimeInterval = -10

    var difficulty: CGFloat { min(1, CGFloat(elapsed / 90)) }
    var scrollSpeed: CGFloat { min(340, 150 + CGFloat(elapsed) * 2.2) }

    init(size: CGSize, daily: Bool, state: GameState) {
        self.daily = daily
        self.state = state
        if daily {
            var h: UInt64 = 0
            for b in GameState.todayKey.utf8 { h = h &* 31 &+ UInt64(b) }
            self.rng = SeededRNG(seed: h)
        } else {
            self.rng = SeededRNG(seed: UInt64.random(in: 1...UInt64.max))
        }
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "#06283D")
        addChild(world)
        buildBackground()
        player = OctopusNode(skin: state.equippedSkin)
        player.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
        world.addChild(player)
        steerTarget = player.position
    }

    private func buildBackground() {
        // Plankton dots (full-speed layer)
        for _ in 0..<36 {
            let d = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.5))
            d.fillColor = .white.withAlphaComponent(0.25)
            d.strokeColor = .clear
            d.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
            d.name = "plankton"
            d.userData = NSMutableDictionary()
            d.userData?["speed"] = CGFloat.random(in: 0.8...1.2)
            addChild(d)
        }
        // Seaweed silhouettes (slow parallax layer)
        for _ in 0..<8 {
            let w = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 14...26), height: CGFloat.random(in: 120...260)))
            w.fillColor = UIColor(hex: "#0A3A52")
            w.strokeColor = .clear
            w.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
            w.name = "seaweed"
            addChild(w)
        }
        // Rising bubbles
        let bubbleAction = SKAction.sequence([
            .run { [weak self] in self?.spawnBubble() },
            .wait(forDuration: 0.9),
        ])
        run(.repeatForever(bubbleAction))
    }

    private func spawnBubble() {
        guard !isOver else { return }
        let b = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...8))
        b.strokeColor = .white.withAlphaComponent(0.35)
        b.fillColor = .clear
        b.lineWidth = 1.5
        b.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: -20)
        addChild(b)
        b.run(.sequence([
            .moveBy(x: CGFloat.random(in: -30...30), y: size.height + 60, duration: TimeInterval.random(in: 3...5)),
            .removeFromParent(),
        ]))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isOver, let t = touches.first, steerTouch == nil else { return }
        steerTouch = t
        let p = t.location(in: self)
        touchBeganAtPoint = p
        touchBeganAt = CACurrentMediaTime()
        touchMovedFar = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = steerTouch, touches.contains(t) else { return }
        let p = t.location(in: self)
        if hypot(p.x - touchBeganAtPoint.x, p.y - touchBeganAtPoint.y) > 24 { touchMovedFar = true }
        steerTarget = clamped(p)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = steerTouch, touches.contains(t) else { return }
        steerTouch = nil
        let now = CACurrentMediaTime()
        let quick = now - touchBeganAt < 0.25
        if quick && !touchMovedFar {
            if now - pendingTapAt < 0.32 {
                pendingTapAt = -10
                doDash()
            } else {
                pendingTapAt = now
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = steerTouch, touches.contains(t) { steerTouch = nil }
    }

    private func clamped(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 50), size.width - 50), y: min(max(p.y, 90), size.height - 60))
    }

    // MARK: - Actions

    func doPulse() {
        guard !isOver, pulseCooldown <= 0 else { return }
        pulseCooldown = 1.1
        state.pulseReady = false
        player.flashRings()
        Haptics.tap(.medium)

        let radius: CGFloat = 155
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = player.position
        ring.strokeColor = UIColor(hex: state.equippedSkin.ringsHex)
        ring.lineWidth = 6
        ring.glowWidth = 10
        ring.setScale(0.15)
        world.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1, duration: 0.22), .fadeAlpha(to: 0, duration: 0.3)]),
            .removeFromParent(),
        ]))

        var hits = 0
        var perfects = 0
        for p in predators where p.state != .stunned {
            let d = hypot(p.position.x - player.position.x, p.position.y - player.position.y)
            if d < radius + p.touchRadius {
                let perfect = (p.state == .telegraph || p.state == .lunge)
                p.stun(perfect: perfect)
                hits += 1
                let gained = perfect ? 150 * max(1, state.combo) : 50
                addScore(gained, at: p.position)
                if perfect {
                    perfects += 1
                    state.combo += 1
                    comboTimer = 4
                    floatText("PERFECT x\(state.combo)", at: p.position + CGPoint(x: 0, y: 44),
                              color: UIColor(hex: "#FFD94D"), size: 26)
                    Haptics.notify(.success)
                    slowMo()
                }
            }
        }
        if perfects > 0 { perfectStuns += perfects }
        if hits == 0 { floatText("miss", at: player.position + CGPoint(x: 0, y: 50), color: .white.withAlphaComponent(0.6), size: 16) }
    }

    func doDash() {
        guard !isOver, dashTimer <= 0, state.ink >= 50 else {
            if state.ink < 50 { floatText("eat shrimp for ink", at: player.position + CGPoint(x: 0, y: 50), color: .white.withAlphaComponent(0.7), size: 15) }
            return
        }
        state.ink -= 50
        state.dashReady = state.ink >= 50
        dashTimer = 0.55
        invulnTimer = max(invulnTimer, 0.7)
        Haptics.tap(.heavy)
        burst(at: player.position, color: .darkGray, count: 14)
    }

    private func slowMo() {
        timeScale = 0.3
        run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.timeScale = 1 }]))
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let rawDt = min(0.05, lastUpdate == 0 ? 0.016 : currentTime - lastUpdate)
        let dt = rawDt * Double(timeScale)
        lastUpdate = currentTime
        guard !isOver else { return }
        elapsed += dt

        // Pending single-tap -> pulse
        if pendingTapAt > 0 && CACurrentMediaTime() - pendingTapAt > 0.32 {
            pendingTapAt = -10
            doPulse()
        }

        // Timers
        pulseCooldown = max(0, pulseCooldown - dt)
        if pulseCooldown == 0 && !state.pulseReady { state.pulseReady = true }
        invulnTimer = max(0, invulnTimer - dt)
        comboTimer -= dt
        if comboTimer <= 0 && state.combo > 0 { state.combo = 0 }

        // Steering
        let toTarget = CGVector(dx: steerTarget.x - player.position.x, dy: steerTarget.y - player.position.y)
        let dist = hypot(toTarget.dx, toTarget.dy)
        if dist > 4 {
            let step = min(dist, 620 * CGFloat(dt) * min(1, dist / 60 + 0.4))
            player.position.x += toTarget.dx / dist * step
            player.position.y += toTarget.dy / dist * step
            player.position = clamped(player.position)
        }
        player.zRotation = max(-0.3, min(0.3, -toTarget.dx / 900))

        // Dash movement
        if dashTimer > 0 {
            dashTimer -= dt
            player.position.y = min(player.position.y + 560 * CGFloat(dt), size.height - 60)
            steerTarget = player.position
            if Int.random(in: 0..<3) == 0 {
                let ghost = SKShapeNode(circleOfRadius: 24)
                ghost.position = player.position
                ghost.fillColor = UIColor(hex: state.equippedSkin.ringsHex).withAlphaComponent(0.35)
                ghost.strokeColor = .clear
                world.addChild(ghost)
                ghost.run(.sequence([.fadeAlpha(to: 0, duration: 0.4), .removeFromParent()]))
            }
            // Dash stuns everything in the way
            for p in predators where p.state != .stunned {
                if hypot(p.position.x - player.position.x, p.position.y - player.position.y) < 70 {
                    p.stun(perfect: false)
                    addScore(50, at: p.position)
                }
            }
        }

        // Score trickle (distance)
        scoreF += 12 * dt
        state.score = Int(scoreF)

        spawn(dt: dt)
        updateEntities(dt: dt)
        checkCollisions()
        updateBackground(dt: dt)

        // Screen shake decay
        if shake > 0.2 {
            shake *= pow(0.001, CGFloat(dt))
            world.position = CGPoint(x: CGFloat.random(in: -shake...shake), y: CGFloat.random(in: -shake...shake))
        } else {
            world.position = .zero
        }
    }

    // MARK: - Spawning

    private func spawn(dt: TimeInterval) {
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnTimer = Double.random(in: 0.7...1.2) * Double(1.15 - difficulty * 0.55)
            spawnPredator()
        }
        preyTimer -= dt
        if preyTimer <= 0 {
            preyTimer = Double.random(in: 0.5...1.1)
            spawnPrey()
        }
    }

    private func spawnPredator() {
        var roll = Double.random(in: 0...1)
        if daily { roll = Double(rng.next() % 1000) / 1000 }
        let kind: PredatorKind
        if roll < 0.42 { kind = .eel }
        else if roll < 0.78 { kind = .lionfish }
        else { kind = difficulty > 0.25 ? .puffer : .eel }
        let p = PredatorNode(kind: kind)
        let x = daily ? CGFloat(rng.next() % UInt64(Int(size.width - 120))) + 60
                      : CGFloat.random(in: 60...(size.width - 60))
        p.position = CGPoint(x: x, y: size.height + 60)
        world.addChild(p)
        predators.append(p)
    }

    private func spawnPrey() {
        let kind: PreyNode.Kind = Double.random(in: 0...1) < 0.78 ? .shrimp : .crab
        let p = PreyNode(kind: kind)
        p.position = CGPoint(x: CGFloat.random(in: 50...(size.width - 50)), y: size.height + 40)
        world.addChild(p)
        prey.append(p)
    }

    // MARK: - Entities & collisions

    private func updateEntities(dt: TimeInterval) {
        for p in predators {
            p.update(dt: dt, playerPos: player.position, scrollSpeed: scrollSpeed, difficulty: difficulty)
            // Near-miss tracking
            let d = hypot(p.position.x - player.position.x, p.position.y - player.position.y)
            if d < 95 && p.state != .stunned { p.wasNear = true }
            if !p.countedPass && p.position.y < player.position.y - 50 {
                p.countedPass = true
                if p.wasNear && p.state != .stunned {
                    addScore(25, at: player.position + CGPoint(x: 0, y: 40))
                    floatText("CLOSE! +25", at: player.position + CGPoint(x: 0, y: 40),
                              color: UIColor(hex: "#8CE8FF"), size: 17)
                }
            }
        }
        predators.removeAll { p in
            if p.position.y < -120 || p.position.x < -140 || p.position.x > size.width + 140 {
                p.removeFromParent(); return true
            }
            return false
        }
        for f in prey { f.update(dt: dt, scrollSpeed: scrollSpeed) }
        prey.removeAll { f in
            if f.position.y < -80 { f.removeFromParent(); return true }
            return false
        }
    }

    private func checkCollisions() {
        // Eat prey
        for f in prey {
            if hypot(f.position.x - player.position.x, f.position.y - player.position.y) < 44 {
                state.ink = min(100, state.ink + f.inkValue)
                state.dashReady = state.ink >= 50
                addScore(f.scoreValue, at: f.position)
                burst(at: f.position, color: UIColor(hex: "#FF9E9E"), count: 6)
                f.removeFromParent()
                prey.removeAll { $0 === f }
                Haptics.tap(.light)
            }
        }
        // Predator hits
        guard invulnTimer <= 0, dashTimer <= 0 else { return }
        for p in predators where p.state != .stunned {
            let r = p.touchRadius * p.xScale + player.radius * 0.75
            if hypot(p.position.x - player.position.x, p.position.y - player.position.y) < r {
                takeDamage(from: p)
                break
            }
        }
    }

    private func takeDamage(from p: PredatorNode) {
        state.hearts -= 1
        state.combo = 0
        invulnTimer = 1.6
        shake = 14
        player.hitFlash()
        Haptics.notify(.error)
        burst(at: player.position, color: .red, count: 10)
        // Knock the predator away so it does not chain-hit
        p.position.y += 120
        if state.hearts <= 0 { gameOver() }
    }

    // MARK: - Game over / revive

    private func gameOver() {
        isOver = true
        burst(at: player.position, color: UIColor(hex: state.equippedSkin.ringsHex), count: 22)
        player.run(.sequence([.fadeAlpha(to: 0, duration: 0.6), .removeFromParent()]))
        let shellsEarned = Int(scoreF) / 60 + perfectStuns * 4 + (daily ? 20 : 0)
        // Small delay so the death reads before the sheet appears
        run(.sequence([.wait(forDuration: 0.7), .run { [weak self] in
            guard let self else { return }
            self.state.endRun(score: Int(self.scoreF), shellsEarned: shellsEarned,
                              perfectStuns: self.perfectStuns, daily: self.daily)
        }]))
    }

    func revive() {
        guard isOver else { return }
        isOver = false
        state.canReviveThisRun = false
        state.showGameOver = false
        state.hearts = 2
        invulnTimer = 2.5
        for p in predators {
            burst(at: p.position, color: .white, count: 6)
            p.removeFromParent()
        }
        predators.removeAll()
        player.alpha = 1
        if player.parent == nil { world.addChild(player) }
        player.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
        steerTarget = player.position
    }

    // MARK: - Juice

    private func addScore(_ n: Int, at pos: CGPoint) {
        scoreF += Double(n)
        state.score = Int(scoreF)
        floatText("+\(n)", at: pos, color: .white, size: 18)
    }

    private func floatText(_ text: String, at pos: CGPoint, color: UIColor, size: CGFloat) {
        let l = SKLabelNode(text: text)
        l.fontName = "Helvetica-Bold"
        l.fontSize = size
        l.fontColor = color
        l.position = pos
        l.zPosition = 50
        world.addChild(l)
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 44, duration: 0.8), .fadeAlpha(to: 0, duration: 0.8)]),
            .removeFromParent(),
        ]))
    }

    private func burst(at pos: CGPoint, color: UIColor, count: Int) {
        for _ in 0..<count {
            let c = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            c.fillColor = color
            c.strokeColor = .clear
            c.position = pos
            world.addChild(c)
            let a = CGFloat.random(in: 0...(.pi * 2))
            let d = CGFloat.random(in: 40...130)
            c.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(a) * d, dy: sin(a) * d), duration: 0.5),
                    .fadeAlpha(to: 0, duration: 0.5),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func updateBackground(dt: TimeInterval) {
        enumerateChildNodes(withName: "plankton") { node, _ in
            let speed = (node.userData?["speed"] as? CGFloat) ?? 1
            node.position.y -= self.scrollSpeed * 0.9 * speed * CGFloat(dt)
            if node.position.y < -10 {
                node.position.y = self.size.height + 10
                node.position.x = CGFloat.random(in: 0...self.size.width)
            }
        }
        enumerateChildNodes(withName: "seaweed") { node, _ in
            node.position.y -= self.scrollSpeed * 0.3 * CGFloat(dt)
            if node.position.y < -160 {
                node.position.y = self.size.height + 160
                node.position.x = CGFloat.random(in: 0...self.size.width)
            }
        }
    }
}
