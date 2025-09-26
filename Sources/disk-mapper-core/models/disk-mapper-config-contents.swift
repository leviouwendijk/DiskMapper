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
