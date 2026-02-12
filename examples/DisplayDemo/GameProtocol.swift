// GameProtocol.swift

public protocol GameRenderer {
    // Ciclo de frame
    func beginFrame()
    func endFrame()

    // Primitivas
    func drawFilledCircle(x: Int16, y: Int16, r: Int16)
    func drawRect(x: Int16, y: Int16, w: Int16, h: Int16)
}

public protocol GameScene {
    mutating func setup()
    mutating func update(nowMs: UInt32, dtMs: UInt32)
    func render<R: GameRenderer>(on renderer: R)
}