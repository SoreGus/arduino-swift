// main.swift
// SSD1306 minimal test using ArduinoSwift runtime
// SAFE: no Foundation, no heap, no String interpolation

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    print("Swift boot\n")

    SSD1306.begin()

    SSD1306.setCursor(col: 0, row: 0)
    SSD1306.print("Arduino Swift")

    SSD1306.setCursor(col: 0, row: 2)
    SSD1306.print("SSD1306 OK")

    SSD1306.setCursor(col: 0, row: 4)
    SSD1306.print("Swift + Arduino")

    var counter: UInt32 = 0

    // buffer fixo C (sem heap)
    var buf: [UInt8] = Array(repeating: 0, count: 16)

    ArduinoRuntime.keepAlive {
        SSD1306.setCursor(col: 0, row: 6)

        // "Count: "
        buf[0] = 67  // C
        buf[1] = 111 // o
        buf[2] = 117 // u
        buf[3] = 110 // n
        buf[4] = 116 // t
        buf[5] = 58  // :
        buf[6] = 32  // space

        // decimal UInt32 -> ASCII
        var v = counter
        var i: UInt8 = 0
        repeat {
            buf[Int(7 + i)] = UInt8(48 + (v % 10))
            v /= 10
            i &+= 1
        } while v > 0

        // reverse digits
        var a = 7
        var b = Int(7 + i - 1)
        while a < b {
            let t = buf[a]
            buf[a] = buf[b]
            buf[b] = t
            a &+= 1
            b &-= 1
        }

        buf[Int(7 + i)] = 0 // null-terminated

        buf.withUnsafeBufferPointer {
            SSD1306.printCStr(
                $0.baseAddress!.withMemoryRebound(
                    to: CChar.self,
                    capacity: buf.count
                ) { $0 }
            )
        }

        counter &+= 1
        delay(500)
    }
}