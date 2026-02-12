// SSD1306.swift
// High-level API with real Canvas (shapes) + stable counter line.
// Backend: Adafruit_GFX + Adafruit_SSD1306

public struct SSD1306 {

    // MARK: - Color
    public enum Color: UInt8 {
        case black = 0
        case white = 1
        case inverse = 2
    }

    // MARK: - Core
    @inline(__always)
    public static func begin(textSize: UInt8 = 1) {
        let ok = arduino_ssd1306_begin_auto()
        if ok == 0 {
            print("SSD1306 begin failed (auto)\n")
            return
        }
        arduino_ssd1306_set_text_size(textSize)
        arduino_ssd1306_set_text_color(Color.white.rawValue)
        clear()
        display()
    }

    @inline(__always)
    public static func begin(i2cAddress: UInt8, textSize: UInt8 = 1) {
        let ok = arduino_ssd1306_begin_addr(i2cAddress)
        if ok == 0 {
            print("SSD1306 begin failed (addr)\n")
            return
        }
        arduino_ssd1306_set_text_size(textSize)
        arduino_ssd1306_set_text_color(Color.white.rawValue)
        clear()
        display()
    }

    @inline(__always)
    public static func clear() { arduino_ssd1306_clear() }

    @inline(__always)
    public static func display() { arduino_ssd1306_display() }

    @inline(__always)
    public static func width() -> Int16 { arduino_ssd1306_width() }

    @inline(__always)
    public static func height() -> Int16 { arduino_ssd1306_height() }

    // MARK: - Text
    @inline(__always)
    public static func setTextSize(_ s: UInt8) { arduino_ssd1306_set_text_size(s) }

    @inline(__always)
    public static func setTextColor(_ c: Color) { arduino_ssd1306_set_text_color(c.rawValue) }

    @inline(__always)
    public static func setCursor(pxX: Int16, pxY: Int16) {
        arduino_ssd1306_set_cursor_px(pxX, pxY)
    }

    @inline(__always)
    public static func print(_ s: StaticString) {
        s.withUTF8Buffer { buf in
            arduino_ssd1306_print_cstr(
                buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count) { $0 }
            )
        }
    }

    @inline(__always)
    public static func printCStr(_ p: UnsafePointer<CChar>) {
        arduino_ssd1306_print_cstr(p)
    }

    // MARK: - Primitives
    @inline(__always)
    public static func pixel(_ x: Int16, _ y: Int16, _ c: Color = .white) {
        arduino_ssd1306_draw_pixel(x, y, c.rawValue)
    }

    @inline(__always)
    public static func line(_ x0: Int16, _ y0: Int16, _ x1: Int16, _ y1: Int16, _ c: Color = .white) {
        arduino_ssd1306_draw_line(x0, y0, x1, y1, c.rawValue)
    }

    @inline(__always)
    public static func rect(_ x: Int16, _ y: Int16, _ w: Int16, _ h: Int16, _ c: Color = .white) {
        arduino_ssd1306_draw_rect(x, y, w, h, c.rawValue)
    }

    @inline(__always)
    public static func fillRect(_ x: Int16, _ y: Int16, _ w: Int16, _ h: Int16, _ c: Color = .white) {
        arduino_ssd1306_fill_rect(x, y, w, h, c.rawValue)
    }

    @inline(__always)
    public static func circle(_ x: Int16, _ y: Int16, _ r: Int16, _ c: Color = .white) {
        arduino_ssd1306_draw_circle(x, y, r, c.rawValue)
    }

    @inline(__always)
    public static func fillCircle(_ x: Int16, _ y: Int16, _ r: Int16, _ c: Color = .white) {
        arduino_ssd1306_fill_circle(x, y, r, c.rawValue)
    }

    // ------------------------------------------------------------
    // MARK: - Canvas
    // ------------------------------------------------------------
    public struct Canvas {

        public enum Shape {
            case pixel(Int16, Int16, Color)
            case line(Int16, Int16, Int16, Int16, Color)
            case rect(Int16, Int16, Int16, Int16, Color)
            case fillRect(Int16, Int16, Int16, Int16, Color)
            case circle(Int16, Int16, Int16, Color)
            case fillCircle(Int16, Int16, Int16, Color)
        }

        public struct Label {
            public var x: Int16
            public var y: Int16
            public var text: StaticString
            public var size: UInt8
            public var color: Color

            public init(x: Int16, y: Int16, text: StaticString, size: UInt8 = 1, color: Color = .white) {
                self.x = x
                self.y = y
                self.text = text
                self.size = size
                self.color = color
            }
        }

        private var shapes: [Shape]
        private var labels: [Label]

        public init(shapeCapacity: Int = 16, labelCapacity: Int = 8) {
            self.shapes = []
            self.labels = []
            self.shapes.reserveCapacity(shapeCapacity)
            self.labels.reserveCapacity(labelCapacity)
        }

        @inline(__always)
        public mutating func add(_ shape: Shape) {
            shapes.append(shape)
        }

        @inline(__always)
        public mutating func addLabel(_ label: Label) {
            labels.append(label)
        }

        public func draw() {
            var i = 0
            while i < shapes.count {
                switch shapes[i] {
                case .pixel(let x, let y, let c):
                    SSD1306.pixel(x, y, c)
                case .line(let x0, let y0, let x1, let y1, let c):
                    SSD1306.line(x0, y0, x1, y1, c)
                case .rect(let x, let y, let w, let h, let c):
                    SSD1306.rect(x, y, w, h, c)
                case .fillRect(let x, let y, let w, let h, let c):
                    SSD1306.fillRect(x, y, w, h, c)
                case .circle(let x, let y, let r, let c):
                    SSD1306.circle(x, y, r, c)
                case .fillCircle(let x, let y, let r, let c):
                    SSD1306.fillCircle(x, y, r, c)
                }
                i &+= 1
            }

            var j = 0
            while j < labels.count {
                SSD1306.setTextSize(labels[j].size)
                SSD1306.setTextColor(labels[j].color)
                SSD1306.setCursor(pxX: labels[j].x, pxY: labels[j].y)
                SSD1306.print(labels[j].text)
                j &+= 1
            }
        }
    }

    // ------------------------------------------------------------
    // MARK: - CounterLine (single-line clear + redraw)
    // ------------------------------------------------------------
    public struct CounterLine {
        public var x: Int16
        public var y: Int16
        public var fieldChars: UInt8
        public var textSize: UInt8
        public var color: Color
        public var prefix: StaticString

        private var lineBuf: [UInt8]   // ASCII field + '\0'
        private var digits: [UInt8]    // reversed digits

        public init(
            x: Int16 = 4,
            y: Int16 = 52,
            fieldChars: UInt8 = 20,
            textSize: UInt8 = 1,
            color: Color = .white,
            prefix: StaticString = "Count: "
        ) {
            self.x = x
            self.y = y
            self.fieldChars = fieldChars
            self.textSize = textSize
            self.color = color
            self.prefix = prefix
            self.lineBuf = Array(repeating: 0, count: Int(fieldChars) + 1)
            self.digits = Array(repeating: 0, count: 10)
        }

        @inline(__always)
        private mutating func buildASCII(_ value: UInt32) {
            let w = Int(fieldChars)

            var i = 0
            while i < w {
                lineBuf[i] = 32 // ' '
                i &+= 1
            }
            lineBuf[w] = 0

            var idx = 0
            prefix.withUTF8Buffer { p in
                while idx < p.count && idx < w {
                    lineBuf[idx] = p[idx]
                    idx &+= 1
                }
            }

            var v = value
            var n = 0
            repeat {
                digits[n] = UInt8(48 + (v % 10))
                v /= 10
                n &+= 1
            } while v > 0 && n < 10

            var j = 0
            while j < n && (idx + j) < w {
                lineBuf[idx + j] = digits[n - 1 - j]
                j &+= 1
            }
        }

        public mutating func draw(_ value: UInt32) {
            let pxW = Int16(Int(fieldChars) * 6 * Int(textSize))
            let pxH = Int16(8 * Int(textSize))

            // clear only this text strip
            SSD1306.fillRect(x, y, pxW, pxH, .black)

            buildASCII(value)

            SSD1306.setTextSize(textSize)
            SSD1306.setTextColor(color)
            SSD1306.setCursor(pxX: x, pxY: y)

            lineBuf.withUnsafeBufferPointer { raw in
                let cstr = raw.baseAddress!.withMemoryRebound(to: CChar.self, capacity: lineBuf.count) { $0 }
                SSD1306.printCStr(cstr)
            }
        }
    }
}