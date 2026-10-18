import Foundation

struct WakeResult: Codable {
    let attempt: UUID
    let message: String
    let completed: Bool
    let accepted: Bool

    static func url(for attempt: UUID) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("io.github.wechatgg.xgimi-agent/WakeResults", isDirectory: true)
            .appendingPathComponent(attempt.uuidString + ".json")
    }

    func save() {
        let url = Self.url(for: attempt)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: url, options: .atomic) }
    }
}
