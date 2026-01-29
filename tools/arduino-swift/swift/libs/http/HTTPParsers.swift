// ============================================================
// ArduinoSwift - HTTP Parsers
// File: swift/libs/http/HTTPParsers.swift
// ============================================================

public enum HTTPParsers {

    public static func indexOf(_ x: U8, in a: [U8], start: Int = 0) -> Int? {
        if start >= a.count { return nil }
        var i = start
        while i < a.count {
            if a[i] == x { return i }
            i += 1
        }
        return nil
    }

    public static func splitCRLF(_ bytes: [U8]) -> [[U8]] {
        var out: [[U8]] = []
        out.reserveCapacity(8)

        var cur: [U8] = []
        cur.reserveCapacity(64)

        var i = 0
        while i < bytes.count {
            if i + 1 < bytes.count, bytes[i] == 13, bytes[i + 1] == 10 {
                out.append(cur)
                cur = []
                i += 2
                continue
            }
            cur.append(bytes[i])
            i += 1
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    public static func trimSpaces(_ bytes: [U8]) -> [U8] {
        var s = 0
        var e = bytes.count
        while s < e, bytes[s] == 32 { s += 1 }
        while e > s, bytes[e - 1] == 32 { e -= 1 }
        if s == 0 && e == bytes.count { return bytes }
        return Array(bytes[s..<e])
    }

    public static func parseIntASCII(_ bytes: [U8]) -> Int {
        var v = 0
        var i = 0
        while i < bytes.count {
            let c = bytes[i]
            if c < 48 || c > 57 { break }
            v = v * 10 + Int(c - 48)
            i += 1
        }
        return v
    }

    public static func intToASCII(_ n: Int) -> [U8] {
        if n == 0 { return [48] }
        var x = n
        var tmp: [U8] = []
        while x > 0 {
            tmp.append(U8(x % 10) + 48)
            x /= 10
        }
        return tmp.reversed()
    }

    public static func parseHeaderLine(_ line: [U8]) -> HTTPHeader? {
        guard let colon = indexOf(58, in: line) else { return nil } // ':'
        var name = Array(line[0..<colon])
        name = HTTPBytes.lowerASCII(trimSpaces(name))

        var value = Array(line[(colon + 1)..<line.count])
        value = trimSpaces(value)
        return HTTPHeader(nameLower: name, value: value)
    }

    public static func splitOnQuestionMark(_ target: [U8]) -> (path: [U8], query: [U8]) {
        if let q = indexOf(63, in: target) { // '?'
            return (Array(target[0..<q]), Array(target[(q + 1)..<target.count]))
        }
        return (target, [])
    }

    public struct ParsedRequestHead: Sendable {
        public let method: HTTPMethod
        public let pathBytes: [U8]
        public let queryBytes: [U8]
        public let headers: [HTTPHeader]
        public let contentLength: Int
    }

    public static func parseRequestHead(_ head: [U8]) -> ParsedRequestHead? {
        let lines = splitCRLF(head)
        if lines.isEmpty { return nil }

        guard let sp1 = indexOf(32, in: lines[0]) else { return nil }
        guard let sp2 = indexOf(32, in: lines[0], start: sp1 + 1) else { return nil }

        let mSlice = lines[0][0..<sp1]
        let tSlice = lines[0][(sp1 + 1)..<sp2]

        guard let method = HTTPMethod.parse(mSlice) else { return nil }
        let target = Array(tSlice)
        let split = splitOnQuestionMark(target)

        var headers: [HTTPHeader] = []
        headers.reserveCapacity(8)

        var cl = 0
        var i = 1
        while i < lines.count {
            let line = lines[i]
            i += 1
            if line.isEmpty { continue }
            if let h = parseHeaderLine(line) {
                headers.append(h)
                if HTTPBytes.eq(h.nameLower, HTTPBytes.ascii("content-length")) {
                    cl = parseIntASCII(h.value)
                }
            }
        }

        return ParsedRequestHead(
            method: method,
            pathBytes: split.path,
            queryBytes: split.query,
            headers: headers,
            contentLength: cl
        )
    }

    public struct ParsedResponseHead: Sendable {
        public let status: Int
        public let headers: [HTTPHeader]
        public let contentLength: Int
        public let contentType: [U8]?
    }

    public static func parseResponseHead(_ head: [U8]) -> ParsedResponseHead? {
        let lines = splitCRLF(head)
        if lines.isEmpty { return nil }

        guard let sp1 = indexOf(32, in: lines[0]) else { return nil }
        guard let sp2 = indexOf(32, in: lines[0], start: sp1 + 1) else { return nil }

        let statusBytes = Array(lines[0][(sp1 + 1)..<sp2])
        let status = parseIntASCII(statusBytes)

        var headers: [HTTPHeader] = []
        headers.reserveCapacity(8)

        var cl = 0
        var ct: [U8]? = nil

        var i = 1
        while i < lines.count {
            let line = lines[i]
            i += 1
            if line.isEmpty { continue }
            if let h = parseHeaderLine(line) {
                headers.append(h)
                if HTTPBytes.eq(h.nameLower, HTTPBytes.ascii("content-length")) {
                    cl = parseIntASCII(h.value)
                } else if HTTPBytes.eq(h.nameLower, HTTPBytes.ascii("content-type")) {
                    ct = h.value
                }
            }
        }

        return ParsedResponseHead(status: status, headers: headers, contentLength: cl, contentType: ct)
    }
}