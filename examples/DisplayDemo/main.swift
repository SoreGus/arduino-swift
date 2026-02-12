// main.swift

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    SSD1306.begin(textSize: 1)

    var game = Game(scene: PhysicsScene(), targetFPS: 60)
    let renderer = SSD1306Renderer()

    game.run(renderer: renderer)
}