// Game+SSD1306.swift

public struct SSD1306Renderer: GameRenderer {
    public init() {}

    @inline(__always)
    public func beginFrame() {
        SSD1306.clear()
    }

    @inline(__always)
    public func endFrame() {
        SSD1306.display()
    }

    @inline(__always)
    public func drawFilledCircle(x: Int16, y: Int16, r: Int16) {
        SSD1306.fillCircle(x, y, r, .white)
    }

    @inline(__always)
    public func drawRect(x: Int16, y: Int16, w: Int16, h: Int16) {
        SSD1306.rect(x, y, w, h, .white)
    }
}