import SpriteKit

// MARK: - Prey (food: fills the ink meter)

final class PreyNode: SKNode {
    enum Kind { case shrimp, crab }
    let kind: Kind
    let inkValue: Double
    let scoreValue: Int
    var velocity: CGVector = .zero
    private var t: TimeInterval = 0

    init(kind: Kind) {
        self.kind = kind
        switch kind {
        case .shrimp: inkValue = 12; scoreValue = 10
        case .crab: inkValue = 30; scoreValue = 25
        }
        super.init()
        if kind == .shrimp {
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 9, startAngle: 0.6, endAngle: 5.4, clockwise: false)
            let s = SKShapeNode(path: path)
            s.strokeColor = UIColor(hex: "#FF9E9E")
            s.lineWidth = 5
            s.lineCap = .round
            addChild(s)
        } else {
            let b = SKShapeNode(circleOfRadius: 11)
            b.fillColor = UIColor(hex: "#FF7B54")
            b.strokeColor = UIColor(hex: "#D95F3B")
            b.lineWidth = 2
            addChild(b)
            for x in [-14.0, 14.0] {
                let claw = SKShapeNode(circleOfRadius: 4)
                claw.position = CGPoint(x: x, y: 6)
                claw.fillColor = UIColor(hex: "#FF7B54")
                claw.strokeColor = .clear
                addChild(claw)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(dt: TimeInterval, scrollSpeed: CGFloat) {
        t += dt
        position.y -= (scrollSpeed * 0.55 + velocity.dy) * CGFloat(dt)
        position.x += (velocity.dx + sin(t * 3) * 24) * CGFloat(dt)
    }
}

// MARK: - Predators

enum PredatorKind: CaseIterable { case eel, lionfish, puffer }
enum PredState { case roam, telegraph, lunge, stunned }

final class PredatorNode: SKNode {
    let kind: PredatorKind
    var state: PredState = .roam
    var stunTimer: TimeInterval = 0
    var telegraphTimer: TimeInterval = 0
    var lungeDir: CGVector = .zero
    var baseSpeed: CGFloat = 60
    private var t: TimeInterval = .random(in: 0...10)
    private var bodyParts: [SKNode] = []
    let touchRadius: CGFloat
    /// Near-miss bonus tracking (set by the scene).
    var wasNear = false
    var countedPass = false

    init(kind: PredatorKind) {
        self.kind = kind
        switch kind {
        case .eel: touchRadius = 26; baseSpeed = 70
        case .lionfish: touchRadius = 30; baseSpeed = 45
        case .puffer: touchRadius = 26; baseSpeed = 40
        }
        super.init()
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        switch kind {
        case .eel:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 34))
            path.addCurve(to: CGPoint(x: 0, y: -34),
                          control1: CGPoint(x: 26, y: 12), control2: CGPoint(x: -26, y: -12))
            let s = SKShapeNode(path: path)
            s.name = "tintable"
            s.strokeColor = UIColor(hex: "#4CAF6D")
            s.lineWidth = 13
            s.lineCap = .round
            addChild(s); bodyParts.append(s)
            let head = SKShapeNode(circleOfRadius: 9)
            head.position = CGPoint(x: 0, y: 34)
            head.fillColor = UIColor(hex: "#3E9E5F")
            head.strokeColor = .clear
            addChild(head); bodyParts.append(head)
        case .lionfish:
            let b = SKShapeNode(circleOfRadius: 16)
            b.name = "tintable"
            b.fillColor = UIColor(hex: "#E4572E")
            b.strokeColor = UIColor(hex: "#B23A1B")
            b.lineWidth = 2
            addChild(b); bodyParts.append(b)
            for i in 0..<10 {
                let a = CGFloat(i) / 10 * .pi * 2
                let spine = SKShapeNode(rectOf: CGSize(width: 3, height: 30))
                spine.position = CGPoint(x: cos(a) * 26, y: sin(a) * 26)
                spine.zRotation = a + .pi / 2
                spine.fillColor = UIColor(hex: "#F2E6C9")
                spine.strokeColor = .clear
                addChild(spine); bodyParts.append(spine)
            }
        case .puffer:
            let b = SKShapeNode(circleOfRadius: 22)
            b.name = "tintable"
            b.fillColor = UIColor(hex: "#F2C14E")
            b.strokeColor = UIColor(hex: "#C99A35")
            b.lineWidth = 2
            addChild(b); bodyParts.append(b)
            for i in 0..<8 {
                let a = CGFloat(i) / 8 * .pi * 2
                let spike = SKShapeNode(path: spikePath())
                spike.position = CGPoint(x: cos(a) * 24, y: sin(a) * 24)
                spike.zRotation = a - .pi / 2
                spike.fillColor = UIColor(hex: "#C99A35")
                spike.strokeColor = .clear
                addChild(spike); bodyParts.append(spike)
            }
        }
    }

    private func spikePath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -5, y: 0)); p.addLine(to: CGPoint(x: 0, y: 10)); p.addLine(to: CGPoint(x: 5, y: 0)); p.closeSubpath()
        return p
    }

    // MARK: Behavior

    func update(dt: TimeInterval, playerPos: CGPoint, scrollSpeed: CGFloat, difficulty: CGFloat) {
        t += dt
        switch state {
        case .stunned:
            stunTimer -= dt
            position.y -= scrollSpeed * 0.4 * CGFloat(dt)
            rotation = sin(t * 2) * 0.4
            if stunTimer <= 0 { state = .roam; rotation = 0 }
        case .telegraph:
            telegraphTimer -= dt
            let flash = (sin(t * 30) > 0)
            tint(flash ? .red : .white)
            if telegraphTimer <= 0 {
                state = .lunge
                tint(.white)
                let d = CGVector(dx: playerPos.x - position.x, dy: playerPos.y - position.y)
                let len = max(hypot(d.dx, d.dy), 1)
                let speed: CGFloat = 420 + difficulty * 60
                lungeDir = CGVector(dx: d.dx / len * speed, dy: d.dy / len * speed)
            }
        case .lunge:
            position.x += lungeDir.dx * CGFloat(dt)
            position.y += (lungeDir.dy - scrollSpeed * 0.3) * CGFloat(dt)
            if lungeClock(dt) { state = .roam }
        case .roam:
            position.y -= (scrollSpeed * 0.75 + baseSpeed * 0.4) * CGFloat(dt)
            position.x += sin(t * 1.7) * 46 * CGFloat(dt)
            // Puffer inflates when close to the player
            if kind == .puffer {
                let d = hypot(playerPos.x - position.x, playerPos.y - position.y)
                let target: CGFloat = d < 150 ? 1.45 : 1.0
                let s = lerp(a: xScale, b: target, t: min(1, dt * 6))
                setScale(s)
            }
            // Eels and lionfish telegraph a lunge when roughly above the player
            if (kind == .eel || kind == .lionfish),
               position.y > playerPos.y, position.y - playerPos.y < 320,
               abs(position.x - playerPos.x) < 130,
               Int.random(in: 0..<1000) < Int(2 + difficulty * 2) {
                state = .telegraph
                telegraphTimer = 0.55
            }
        }
    }

    private var lungeT: TimeInterval = 0
    private func lungeClock(_ dt: TimeInterval) -> Bool {
        if state != .lunge { lungeT = 0; return false }
        lungeT += dt
        if lungeT > 0.55 { lungeT = 0; return true }
        return false
    }

    private func tint(_ c: UIColor) {
        for p in bodyParts where p.name == "tintable" {
            (p as? SKShapeNode)?.strokeColor = c == .white ? originalStroke(p) : c
        }
    }

    private func originalStroke(_ p: SKNode) -> UIColor {
        switch kind {
        case .eel: return UIColor(hex: "#4CAF6D")
        case .lionfish: return UIColor(hex: "#B23A1B")
        case .puffer: return UIColor(hex: "#C99A35")
        }
    }

    func stun(perfect: Bool) {
        state = .stunned
        stunTimer = perfect ? 4.0 : 2.6
        tint(.white)
        removeAction(forKey: "stars")
        for i in 0..<3 {
            let a = CGFloat(i) / 3 * .pi * 2
            let star = SKLabelNode(text: "✦")
            star.fontSize = 18
            star.fontColor = perfect ? UIColor(hex: "#FFD94D") : .white
            star.position = CGPoint(x: cos(a) * 30, y: sin(a) * 30)
            star.alpha = 0.9
            addChild(star)
            star.run(.sequence([.wait(forDuration: stunTimer), .fadeOut(withDuration: 0.2), .removeFromParent()]), withKey: "stars")
            let orbit = SKAction.sequence([.move(by: CGVector(dx: -cos(a) * 14, dy: 26), duration: 0.8), .removeFromParent()])
            // stars drift up while stunned; they are cleaned when stun ends
            if !perfect { star.run(orbit) }
        }
    }

    private func lerp(a: CGFloat, b: CGFloat, t: CGFloat) -> CGFloat { a + (b - a) * t }
}
