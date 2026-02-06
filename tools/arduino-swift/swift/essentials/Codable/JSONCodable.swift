public struct JSONCodable {
    private let serialization = JSONSerialization()
    public init() {}

    public func decode(
        _ type: EssentialsJSONValue.Type = EssentialsJSONValue.self,
        from data: Data
    ) -> (EssentialsJSONValue?, EssentialsError) {
        _ = type
        return serialization.jsonObject(with: data)
    }
}
