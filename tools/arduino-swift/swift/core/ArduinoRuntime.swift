// ArduinoRuntime.swift
// Tiny cooperative runtime:
// - Register tickables with ArduinoRuntime.add(...)
// - Use ArduinoRuntime.keepAlive() (or keepAlive { ... })
// - Use ArduinoRuntime.delay(ms:) for cooperative delays that keep ticking

public protocol ArduinoTickable: AnyObject {
    func tick()
}

public enum ArduinoRuntime {
    private static var items: [ArduinoTickable] = []

    @inline(__always)
    public static func add(_ item: ArduinoTickable) {
        items.append(item)
    }

    @inline(__always)
    public static var hasItems: Bool {
        !items.isEmpty
    }

    @inline(__always)
    public static func removeAll() {
        items.removeAll(keepingCapacity: false)
    }

    @inline(__always)
    public static func tickAll() {
        for it in items {
            it.tick()
        }
    }

    // --------------------------------------------------
    // keepAlive: simple
    // --------------------------------------------------
    @inline(__always)
    public static func keepAlive() -> Never {
        while true {
            tickAll()
            arduino_delay_ms(1)
        }
    }

    // --------------------------------------------------
    // keepAlive: custom loop body
    // --------------------------------------------------
    @inline(__always)
    public static func keepAlive(_ body: () -> Void) -> Never {
        while true {
            tickAll()
            body()
            arduino_delay_ms(1)
        }
    }

    // --------------------------------------------------
    // Cooperative delay (IMPORTANT)
    // This keeps the runtime ticking while waiting.
    // --------------------------------------------------
    public static func delay(ms: U32) {
        if ms == 0 { return }

        let start = arduino_millis()
        while (arduino_millis() &- start) < ms {
            tickAll()
            arduino_delay_ms(1)
        }
    }
}
