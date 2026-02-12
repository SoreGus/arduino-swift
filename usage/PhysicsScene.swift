// PhysicsScene.swift

public struct PhysicsScene: GameScene {
    // Tela
    private let minX: Int16 = 0
    private let maxX: Int16 = 127
    private let minY: Int16 = 0
    private let maxY: Int16 = 63

    // Quantidades
    private let ballCount = 5
    private let boxCount  = 3

    // Geometria
    private let ballR: Int16 = 4
    private let boxS:  Int16 = 10

    // Física
    private let gravity: Float = 0.20
    private let restitution: Float = 0.82
    private let damping: Float = 0.996

    // Impulso periódico
    private let kickIntervalMs: UInt32 = 5_000
    private let kickYBall: Float = -5.4
    private let kickYBox:  Float = -4.8
    private let kickXMagBall: Float = 0.70
    private let kickXMagBox:  Float = 0.55
    private var lastKickMs: UInt32 = 0

    // Bolas
    private var bx: [Float] = [14, 34, 54, 74, 94]
    private var by: [Float] = [ 8, 10, 12, 14, 16]
    private var bvx:[Float] = [1.4, -1.1, 1.8, -1.5, 1.2]
    private var bvy:[Float] = [0.0, 0.0, 0.0, 0.0, 0.0]

    // Cubos
    private var sx: [Float] = [20, 58, 96]
    private var sy: [Float] = [24, 26, 28]
    private var svx:[Float] = [-1.0, 1.3, -1.2]
    private var svy:[Float] = [0.0, 0.0, 0.0]

    public init() {}

    @inline(__always)
    private func absf(_ v: Float) -> Float { v < 0 ? -v : v }

    public mutating func setup() {
        lastKickMs = arduino_millis()
    }

    public mutating func update(nowMs: UInt32, dtMs: UInt32) {
        _ = dtMs // passo fixo por frame

        // Impulso global a cada 5s
        if (nowMs &- lastKickMs) >= kickIntervalMs {
            var i = 0
            while i < ballCount {
                bvy[i] += kickYBall
                bvx[i] += (bvx[i] >= 0 ? kickXMagBall : -kickXMagBall)
                i &+= 1
            }

            var j = 0
            while j < boxCount {
                svy[j] += kickYBox
                svx[j] += (svx[j] >= 0 ? -kickXMagBox : kickXMagBox)
                j &+= 1
            }

            lastKickMs = nowMs
        }

        // -------- Bolas: integração + parede --------
        let bLeft   = Float(Int(minX) + Int(ballR))
        let bRight  = Float(Int(maxX) - Int(ballR))
        let bTop    = Float(Int(minY) + Int(ballR))
        let bBottom = Float(Int(maxY) - Int(ballR))

        var i = 0
        while i < ballCount {
            bvy[i] += gravity
            bvx[i] *= damping
            bvy[i] *= damping

            bx[i] += bvx[i]
            by[i] += bvy[i]

            if bx[i] <= bLeft {
                bx[i] = bLeft
                bvx[i] = -bvx[i] * restitution
            } else if bx[i] >= bRight {
                bx[i] = bRight
                bvx[i] = -bvx[i] * restitution
            }

            if by[i] <= bTop {
                by[i] = bTop
                bvy[i] = -bvy[i] * restitution
            } else if by[i] >= bBottom {
                by[i] = bBottom
                bvy[i] = -bvy[i] * restitution
                if absf(bvy[i]) < 0.22 { bvy[i] = 0 }
            }

            i &+= 1
        }

        // -------- Cubos: integração + parede --------
        let sMinX = Float(minX)
        let sMaxX = Float(Int(maxX) - Int(boxS) + 1)
        let sMinY = Float(minY)
        let sMaxY = Float(Int(maxY) - Int(boxS) + 1)

        var j = 0
        while j < boxCount {
            svy[j] += gravity
            svx[j] *= damping
            svy[j] *= damping

            sx[j] += svx[j]
            sy[j] += svy[j]

            if sx[j] <= sMinX {
                sx[j] = sMinX
                svx[j] = -svx[j] * restitution
            } else if sx[j] >= sMaxX {
                sx[j] = sMaxX
                svx[j] = -svx[j] * restitution
            }

            if sy[j] <= sMinY {
                sy[j] = sMinY
                svy[j] = -svy[j] * restitution
            } else if sy[j] >= sMaxY {
                sy[j] = sMaxY
                svy[j] = -svy[j] * restitution
                if absf(svy[j]) < 0.22 { svy[j] = 0 }
            }

            j &+= 1
        }

        // -------- Bola x Bola --------
        var a = 0
        while a < ballCount {
            var b = a + 1
            while b < ballCount {
                let dx = bx[a] - bx[b]
                let dy = by[a] - by[b]
                let rr = Float((ballR + ballR) * (ballR + ballR))
                let d2 = dx * dx + dy * dy

                if d2 <= rr {
                    let tvx = bvx[a], tvy = bvy[a]
                    bvx[a] = bvx[b] * 0.95
                    bvy[a] = bvy[b] * 0.95
                    bvx[b] = tvx * 0.95
                    bvy[b] = tvy * 0.95

                    bx[a] += (bvx[a] >= 0 ? 0.8 : -0.8)
                    by[a] += (bvy[a] >= 0 ? 0.8 : -0.8)
                    bx[b] += (bvx[b] >= 0 ? 0.8 : -0.8)
                    by[b] += (bvy[b] >= 0 ? 0.8 : -0.8)
                }

                b &+= 1
            }
            a &+= 1
        }

        // -------- Cubo x Cubo --------
        a = 0
        while a < boxCount {
            var b = a + 1
            while b < boxCount {
                let aL = sx[a], aR = sx[a] + Float(boxS), aT = sy[a], aB = sy[a] + Float(boxS)
                let bL = sx[b], bR = sx[b] + Float(boxS), bT = sy[b], bB = sy[b] + Float(boxS)

                let overlap = (aL <= bR) && (aR >= bL) && (aT <= bB) && (aB >= bT)
                if overlap {
                    let tvx = svx[a], tvy = svy[a]
                    svx[a] = svx[b] * 0.93
                    svy[a] = svy[b] * 0.93
                    svx[b] = tvx * 0.93
                    svy[b] = tvy * 0.93

                    sx[a] += (svx[a] >= 0 ? 0.8 : -0.8)
                    sy[a] += (svy[a] >= 0 ? 0.8 : -0.8)
                    sx[b] += (svx[b] >= 0 ? 0.8 : -0.8)
                    sy[b] += (svy[b] >= 0 ? 0.8 : -0.8)
                }

                b &+= 1
            }
            a &+= 1
        }

        // -------- Bola x Cubo --------
        i = 0
        while i < ballCount {
            j = 0
            while j < boxCount {
                let left   = sx[j]
                let right  = sx[j] + Float(boxS)
                let top    = sy[j]
                let bottom = sy[j] + Float(boxS)

                var nx = bx[i]
                if nx < left { nx = left }
                if nx > right { nx = right }

                var ny = by[i]
                if ny < top { ny = top }
                if ny > bottom { ny = bottom }

                let dx = bx[i] - nx
                let dy = by[i] - ny
                let d2 = dx * dx + dy * dy
                let r2 = Float(ballR * ballR)

                if d2 <= r2 {
                    let tvx = bvx[i], tvy = bvy[i]
                    bvx[i] = svx[j] * 0.92
                    bvy[i] = svy[j] * 0.92
                    svx[j] = tvx * 0.92
                    svy[j] = tvy * 0.92

                    bx[i] += (bvx[i] >= 0 ? 1.0 : -1.0)
                    by[i] += (bvy[i] >= 0 ? 1.0 : -1.0)
                    sx[j] += (svx[j] >= 0 ? 0.8 : -0.8)
                    sy[j] += (svy[j] >= 0 ? 0.8 : -0.8)
                }

                j &+= 1
            }
            i &+= 1
        }
    }

    public func render<R: GameRenderer>(on renderer: R) {
        var i = 0
        while i < ballCount {
            renderer.drawFilledCircle(x: Int16(bx[i]), y: Int16(by[i]), r: ballR)
            i &+= 1
        }

        var j = 0
        while j < boxCount {
            renderer.drawRect(x: Int16(sx[j]), y: Int16(sy[j]), w: boxS, h: boxS)
            j &+= 1
        }
    }
}