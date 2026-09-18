import SpriteKit

// MARK: - Player: the blue-ringed octopus

final class OctopusNode: SKNode {
    let skin: Skin
    private let body: SKShapeNode
    private var ringNodes: [SKShapeNode] = []
    private var armNodes: [SKShapeNode] = []
    let radius: CGFloat = 30

    init(skin: Skin) {
        self.skin = skin
        let mantle = UIColor(hex: skin.mantleHex)
        let arms = UIColor(hex: skin.armsHex)

        body = SKShapeNode(circleOfRadius: 30)
        body.fillColor = mantle
        body.strokeColor = mantle.withAlphaComponent(0.6)
        body.lineWidth = 2
        super.init()

        addChild(body)

        // Glowing blue rings on the mantle (the signature look)
        let ringColor = UIColor(hex: skin.ringsHex)
        let ringPositions: [CGPoint] = [
            CGPoint(x: -14, y: 8), CGPoint(x: 0, y: 14), CGPoint(x: 14, y: 8),
            CGPoint(x: -18, y: -6), CGPoint(x: 0, y: 0), CGPoint(x: 18, y: -6),
            CGPoint(x: -9, y: -18), CGPoint(x: 9, y: -18),
        ]
        for p in ringPositions {
            let r = SKShapeNode(circleOfRadius: 5)
            r.position = p
            r.fillColor = ringColor.withAlphaComponent(0.55)
            r.strokeColor = ringColor
            r.lineWidth = 1.5
            r.glowWidth = 4
            addChild(r)
            ringNodes.append(r)
        }

        // Eyes (cute sells)
        for x in [-9.0, 9.0] {
            let white = SKShapeNode(circleOfRadius: 6.5)
            white.position = CGPoint(x: x, y: 20)
            white.fillColor = .white
            white.strokeColor = .clear
            let pupil = SKShapeNode(circleOfRadius: 3)
            pupil.fillColor = .black
            pupil.strokeColor = .clear
            white.addChild(pupil)
            addChild(white)
        }

        // Eight wiggling arms
        for i in 0..<8 {
            let angle = CGFloat(i) / 8 * .pi * 2
            let path = CGMutablePath()
            let start = CGPoint(x: cos(angle) * 22, y: sin(angle) * 22 - 8)
            path.move(to: start)
            path.addQuadCurve(to: CGPoint(x: cos(angle) * 52, y: sin(angle) * 52 - 26),
                              control: CGPoint(x: cos(angle + 0.35) * 44, y: sin(angle + 0.35) * 44 - 14))
            let arm = SKShapeNode(path: path)
            arm.strokeColor = arms
            arm.lineWidth = 7
            arm.lineCap = .round
            addChild(arm)
            armNodes.append(arm)

            let wiggle = SKAction.sequence([
                SKAction.rotate(byAngle: 0.12, duration: 0.5 + Double(i % 3) * 0.12),
                SKAction.rotate(byAngle: -0.12, duration: 0.5 + Double(i % 3) * 0.12),
            ])
            arm.run(.repeatForever(wiggle))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The venom-ring flash: the money animation.
    func flashRings() {
        let ringColor = UIColor(hex: skin.ringsHex)
        for (i, r) in ringNodes.enumerated() {
            let pop = SKAction.sequence([
                .wait(forDuration: Double(i) * 0.015),
                .group([
                    .scale(to: 1.9, duration: 0.12),
                    .customAction(withDuration: 0.12) { node, _ in
                        (node as? SKShapeNode)?.fillColor = ringColor
                        (node as? SKShapeNode)?.glowWidth = 14
                    },
                ]),
                .group([
                    .scale(to: 1.0, duration: 0.35),
                    .customAction(withDuration: 0.35) { node, _ in
                        (node as? SKShapeNode)?.fillColor = ringColor.withAlphaComponent(0.55)
                        (node as? SKShapeNode)?.glowWidth = 4
                    },
                ]),
            ])
            r.run(pop)
        }
    }

    func hitFlash() {
        let blink = SKAction.sequence([.fadeAlpha(to: 0.25, duration: 0.08), .fadeAlpha(to: 1, duration: 0.12)])
        run(.repeat(blink, count: 4))
    }
}
