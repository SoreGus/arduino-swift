// JSON.swift

public enum JSON {
    @inline(__always)
    public static func parse(_ bytes: [U8]) -> EssentialsJSONValue? {
        let (v, e) = JSONSerialization().jsonObject(with: Data(bytes))
        return e == .none ? v : nil
    }

    @inline(__always)
    public static func serialize(_ value: EssentialsJSONValue) -> [U8] {
        JSONSerialization.data(from: value).toArray()
    }
}
