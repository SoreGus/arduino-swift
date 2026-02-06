public struct JSONEncoder {
    public init() {}

    public func encode<T: Encodable>(_ value: T) -> Data? {
        do {
            let encoder = _JSONEncoderImpl()
            try value.encode(to: encoder)
            return JSONSerialization().data(from: encoder.node)
        } catch {
            return nil
        }
    }
}
