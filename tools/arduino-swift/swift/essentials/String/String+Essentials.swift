public extension String {
    var utf8Data: Data {
        Data(self.utf8)
    }
}

public extension Data {
    init(utf8 string: String) {
        self.init(string.utf8)
    }

    func utf8String() -> String? {
        let text = String(decoding: storage, as: UTF8.self)
        return Array(text.utf8) == storage ? text : nil
    }
}
