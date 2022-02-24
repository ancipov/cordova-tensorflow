
import Foundation

extension Decodable {
    init?(from: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: from, options: .prettyPrinted) else { return nil }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(Self.self, from: data) else { return nil }
        self = decoded
    }
}
