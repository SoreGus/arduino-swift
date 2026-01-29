// ============================================================
// ArduinoSwift - HTTP Bytes Utilities
// File: swift/libs/http/HTTPBytes.swift
// ============================================================

public enum HTTPBytes {
    @inline(__always)
    public static func ascii(_ s: String) -> [U8] { Array(s.utf8) }

    @inline(__always)
    public static func toString(_ bytes: [U8]) -> String {
        // Embedded-safe: avoids String.Encoding usage.
        String(decoding: bytes, as: UTF8.self)
    }

    @inline(__always)
    public static func eq(_ a: [U8], _ b: [U8]) -> Bool {
        if a.count != b.count { return false }
        var i = 0
        while i < a.count {
            if a[i] != b[i] { return false }
            i += 1
        }
        return true
    }

    @inline(__always)
    public static func lowerASCII(_ bytes: [U8]) -> [U8] {
        var out = bytes
        var i = 0
        while i < out.count {
            let c = out[i]
            if c >= 65 && c <= 90 { out[i] = c &+ 32 } // A-Z -> a-z
            i += 1
        }
        return out
    }
}