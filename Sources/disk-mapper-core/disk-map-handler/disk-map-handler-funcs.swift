import Foundation

extension DiskMapHandler {
    public func relativePath(fromAbs abs: URL) throws -> String {
        let rootURL = URL(fileURLWithPath: cfg.root).standardizedFileURL
        let absStd = abs.standardizedFileURL

        guard absStd.path.hasPrefix(rootURL.path) else {
            throw DiskMapError.pathEscape
        }
        let rel = String(absStd.path.dropFirst(rootURL.path.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return rel.isEmpty ? "." : rel
    }

    public func mapActionString(_ s: String) -> DiskMapAction? {
        switch s.lowercased() {
        case "terminal", "nvim", "ghostty": return .terminal
        case "finder": return .finder
        case "open", "system_default", "default": return .system_default
        default: return nil
        }
    }

    public func mapPreferred(_ p: PreferredOpenMethod) -> DiskMapAction {
        switch p {
        case .terminal: return .terminal
        case .finder: return .finder
        case .system_default: return .system_default
        }
    }

    // helper: quick heuristic to distinguish bundle identifiers from display names
    public func isLikelyBundleID(_ s: String) -> Bool {
        // crude but effective: bundle IDs have dots and typically no spaces
        return s.contains(".") && !s.contains(" ")
    }

    // Accept “…/Foo.app” or “…/Foo.app/Contents/MacOS/foo”
    public func normalizeAppURL(_ path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "app" { return url }
        return url
            .deletingLastPathComponent()    // MacOS
            .deletingLastPathComponent()    // Contents
            .deletingLastPathComponent()    // *.app
    }

    public func shellPath() -> String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    // POSIX single-quote (safe for spaces/specials)
    // a'b  ->  'a'\''b'
    public func shQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // func launchTerminalCLI(appPath: String, argv: [String]) throws {
    //     let p = Process()
    //     p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    //     p.arguments = ["-na", appPath, "--args", "-e"] + argv
    //     try p.run()
    // }

    public func launchTerminalCLI(appPath: String, argv: [String]) throws {
        // Build the exact command you already intended, then hand it to a login shell
        let userCmd = argv.map(shQuote).joined(separator: " ")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-na", appPath, "--args", "-e",
                       shellPath(), "-l", "-c", userCmd]
        try p.run()
    }

    public func runAppleScriptInTerminal(_ argv: [String]) throws {
        // Shell-escape minimal: backslashes + quotes
        let joined = argv.map {
            $0.replacingOccurrences(of: "\\", with: "\\\\")
              .replacingOccurrences(of: "\"", with: "\\\"")
        }.joined(separator: " ")

        let script = """
        tell application "Terminal"
          do script "\(joined)"
          activate
        end tell
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try p.run()
    }
}
