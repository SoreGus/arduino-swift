public struct JSONSerialization {
    public init() {}

    public func jsonObject(with data: Data) -> (EssentialsJSONValue?, EssentialsError) {
        var parser = EssentialsJSONParser(bytes: data.toArray())
        return parser.parse()
    }
}
