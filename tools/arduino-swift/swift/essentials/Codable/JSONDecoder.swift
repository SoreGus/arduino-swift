public struct JSONDecoder {
    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            let node = try JSONSerialization().jsonValue(from: data)
            let decoder = _JSONDecoderImpl(node: node)
            return try T(from: decoder)
        } catch {
            return nil
        }
    }
}
