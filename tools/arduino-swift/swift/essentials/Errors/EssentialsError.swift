// EssentialsError.swift
// Central error type for Essentials (Embedded Swift friendly)

public enum EssentialsError: Error, Sendable, Equatable {
    // No error (used by parser APIs that return tuple instead of throws)
    case none

    // JSON lexical/syntax
    case invalidJSON
    case unexpectedEOF
    case invalidNumber
    case unsupportedEscape
    case unsupportedUnicodeEscape

    // Codable / semantic mapping
    case typeMismatch
    case keyNotFound
    case valueNotFound
    case dataCorrupted
    case outOfRange

    // Generic fallback
    case unsupported
}

public extension EssentialsError {
    @inline(__always)
    var isParserError: Bool {
        switch self {
        case .invalidJSON, .unexpectedEOF, .invalidNumber, .unsupportedEscape, .unsupportedUnicodeEscape:
            return true
        default:
            return false
        }
    }

    @inline(__always)
    var isCodableError: Bool {
        switch self {
        case .typeMismatch, .keyNotFound, .valueNotFound, .dataCorrupted, .outOfRange:
            return true
        default:
            return false
        }
    }
}