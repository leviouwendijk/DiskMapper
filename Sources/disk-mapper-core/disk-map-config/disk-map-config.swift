import Foundation

public struct DiskMapConfig: Decodable {
    public let root: String
    public let preferred_open_method: PreferredOpenMethod?
    public let terminal: TerminalConfig?
    public let finder: FinderConfig?
    public let safe_restrict_to_root: Bool?

    public static func load() throws -> DiskMapConfig {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("dotfiles/disk-mapper/config.json"),
            home.appendingPathComponent("disk-mapper/config.json"),
        ]
        for url in candidates {
            if fm.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(DiskMapConfig.self, from: data)
            }
        }

        throw NSError(domain: "DiskMapper", code: 64, userInfo: [NSLocalizedDescriptionKey: "No config found"])
    }
}
