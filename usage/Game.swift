// Game.swift

public struct Game<S: GameScene> {
    private var scene: S
    private let targetFrameMs: UInt32
    private var lastMs: UInt32 = 0
    private var started: Bool = false

    public init(scene: S, targetFPS: UInt16 = 60) {
        self.scene = scene
        self.targetFrameMs = targetFPS == 0 ? 16 : UInt32(1000 / UInt32(targetFPS))
    }

    @inline(__always)
    public mutating func start() {
        if started { return }
        scene.setup()
        lastMs = arduino_millis()
        started = true
    }

    @inline(__always)
    public mutating func tick<R: GameRenderer>(renderer: R) {
        if !started { start() }

        let now = arduino_millis()
        let dt = now &- lastMs
        if dt < targetFrameMs { return }
        lastMs = now

        scene.update(nowMs: now, dtMs: dt)

        renderer.beginFrame()
        scene.render(on: renderer)
        renderer.endFrame()
    }

    public mutating func run<R: GameRenderer>(renderer: R) {
        start()
        ArduinoRuntime.keepAlive {
            self.tick(renderer: renderer)
        }
    }
}