import Foundation

public enum PreferredOpenMethod: String, Decodable {
    case terminal
    case finder
    case system_default
}

public struct TerminalAction: Decodable {
    public let use_command: String
    public let arguments: [String]?
}

public struct TerminalDefaultAction: Decodable {
    public let file: TerminalAction
    public let directory: TerminalAction
}

public struct TerminalConfig: Decodable {
    public let terminal_application: String?   // e.g. /Applications/Ghostty.app/Contents/MacOS/ghostty
    public let default_action: TerminalDefaultAction
}

public struct FinderDefaultAction: Decodable {
    // "view" (reveal in Finder, do NOT open) | "edit" (open with text_editor)
    public let file: String
    public let text_editor: String?            // e.g. "TextEdit" or "Sublime Text"
}

public struct FinderConfig: Decodable {
    public let default_action: FinderDefaultAction
}

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
