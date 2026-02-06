public enum EssentialsError: Error, Equatable, Sendable {
    case outOfBounds
    case invalidArgument

    case invalidUTF8
    case invalidBase64

    case invalidJSON
    case missingKey(String)
    case typeMismatch(expected: String, got: String)
    case invalidNumber

    case invalidURL
}
