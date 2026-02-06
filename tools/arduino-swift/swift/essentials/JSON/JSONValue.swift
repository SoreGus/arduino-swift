public enum EssentialsJSONValue {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([EssentialsJSONValue])
    case object([(String, EssentialsJSONValue)])
}