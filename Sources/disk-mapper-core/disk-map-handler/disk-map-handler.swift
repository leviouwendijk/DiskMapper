import Foundation
import AppKit

public enum DiskMapAction: String {
    case terminal
    case finder
    case system_default
}

public enum DiskMapError: Error, LocalizedError {
    case missingRel
    case pathEscape
    case unsupportedAction(String)
    case configMissingTerminal
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingRel: return "Missing relative path"
        case .pathEscape: return "Resolved path escapes configured root"
        case .unsupportedAction(let a): return "Unsupported action: \(a)"
        case .configMissingTerminal: return "Terminal configuration missing"
        case .launchFailed(let d): return "Launch failed: \(d)"
        }
    }
}

public struct DiskMapResolved {
    public let action: DiskMapAction
    public let absURL: URL
    public let line: Int?
    public let isDirectory: Bool
}

public final class DiskMapHandler {
    let cfg: DiskMapConfig
    public init(cfg: DiskMapConfig) { self.cfg = cfg }

    // // Accepts either a diskmap:// URL or direct (action, rel, line)
    // public func resolve(url: URL?) throws -> DiskMapResolved {
    //     let rootURL = URL(fileURLWithPath: cfg.root).standardizedFileURL

    //     var actionStr: String?
    //     var rel: String?
    //     var line: Int?

    //     if let url {
    //         // diskmap://<hostAction>?rel=...&line=N  OR  diskmap://?rel=...
    //         actionStr = url.host
    //         if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
    //             let items = comps.queryItems ?? []
    //             rel = items.first(where: { $0.name == "rel" })?.value
    //             if let l = items.first(where: { $0.name == "line" })?.value { line = Int(l) }
    //             // Support also path style: diskmap://terminal/relative/path
    //             if (rel == nil || rel?.isEmpty == true) && !url.path.isEmpty {
    //                 rel = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    //             }
    //         }
    //     } else {
    //         throw DiskMapError.missingRel
    //     }

    //     guard let relPath = rel, !relPath.isEmpty else { throw DiskMapError.missingRel }

    //     let absURL = rootURL.appendingPathComponent(relPath).standardizedFileURL
    //     if (cfg.safe_restrict_to_root ?? true) && absURL.path.hasPrefix(rootURL.path) == false {
    //         throw DiskMapError.pathEscape
    //     }

    //     var isDir: ObjCBool = false
    //     FileManager.default.fileExists(atPath: absURL.path, isDirectory: &isDir)

    //     // Decide action
    //     let preferred = cfg.preferred_open_method ?? .system_default
    //     let picked: DiskMapAction = {
    //         if let a = actionStr, !a.isEmpty, let mapped = mapActionString(a) { return mapped }
    //         return mapPreferred(preferred)
    //     }()

    //     return DiskMapResolved(action: picked, absURL: absURL, line: line, isDirectory: isDir.boolValue)
    // }

    // Accepts a diskmap:// URL in multiple shapes, tolerates sloppy variants,
    // and canonically resolves to an absolute file URL under cfg.root.
    public func resolve(url: URL?) throws -> DiskMapResolved {
        guard let url else { throw DiskMapError.missingRel }

        let rootURL = URL(fileURLWithPath: cfg.root).standardizedFileURL

        var actionStr: String?
        var rel: String?
        var line: Int?

        // Host can be the action, or sloppy "rel" / "rel=<path>"
        if let host = url.host, !host.isEmpty {
            let lower = host.lowercased()
            if lower == "rel" {
                // sloppy "diskmap://rel?=path" → handle below
                actionStr = nil
            } else if lower.hasPrefix("rel=") {
                // sloppy "diskmap://rel=path"
                rel = String(host.dropFirst("rel=".count))
                actionStr = nil
            } else {
                actionStr = host
            }
        }

        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Standard query items
            if rel == nil {
                rel = comps.queryItems?.first(where: { $0.name == "rel" })?.value
            }
            if line == nil,
               let l = comps.queryItems?.first(where: { $0.name == "line" })?.value,
               let n = Int(l) {
                line = n
            }

            // Super-sloppy "diskmap://rel?=path"
            if rel == nil,
               (url.host?.lowercased() == "rel"),
               let pq = comps.percentEncodedQuery,
               pq.hasPrefix("=") {
                rel = String(pq.dropFirst()).removingPercentEncoding
            }

            // Path-style:
            // - diskmap://terminal/relative/path
            // - diskmap:///relative/path
            if rel == nil {
                let p = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                // let p = url.path
                if !p.isEmpty { rel = p }
            }

            // Optional fragment like #L123
            if line == nil,
               let frag = comps.fragment,
               frag.uppercased().hasPrefix("L"),
               let n = Int(frag.dropFirst()) {
                line = n
            }
        }

        guard let relPathRaw = rel, !relPathRaw.isEmpty else {
            throw DiskMapError.missingRel
        }

        // If caller accidentally passed an absolute path as "rel",
        // keep behavior sane: if it's under root, downshift to a relative.
        var relPath = relPathRaw
        if relPath.hasPrefix("/") {
            let absCandidate = URL(fileURLWithPath: relPath).standardizedFileURL
            if absCandidate.path.hasPrefix(rootURL.path) {
                relPath = String(absCandidate.path.dropFirst(rootURL.path.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if relPath.isEmpty { relPath = "." }
            }
        }

        let absURL = rootURL.appendingPathComponent(relPath).standardizedFileURL

        if (cfg.safe_restrict_to_root ?? true) && !absURL.path.hasPrefix(rootURL.path) {
            throw DiskMapError.pathEscape
        }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: absURL.path, isDirectory: &isDir)

        // Decide action (host wins, else preferred)
        let preferred = cfg.preferred_open_method ?? .system_default
        let picked: DiskMapAction = {
            if let a = actionStr, !a.isEmpty, let mapped = mapActionString(a) { return mapped }
            return mapPreferred(preferred)
        }()

        return DiskMapResolved(action: picked, absURL: absURL, line: line, isDirectory: isDir.boolValue)
    }

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

    private func mapActionString(_ s: String) -> DiskMapAction? {
        switch s.lowercased() {
        case "terminal", "nvim", "ghostty": return .terminal
        case "finder": return .finder
        case "open", "system_default", "default": return .system_default
        default: return nil
        }
    }

    private func mapPreferred(_ p: PreferredOpenMethod) -> DiskMapAction {
        switch p {
        case .terminal: return .terminal
        case .finder: return .finder
        case .system_default: return .system_default
        }
    }

    // Execute according to config
    public func execute(_ r: DiskMapResolved) throws {
        switch r.action {
        case .system_default:
            NSWorkspace.shared.open(r.absURL)

        case .finder:
            try executeFinder(r)

        case .terminal:
            try executeTerminal(r)
        }
    }

    // helper: quick heuristic to distinguish bundle identifiers from display names
    private func isLikelyBundleID(_ s: String) -> Bool {
        // crude but effective: bundle IDs have dots and typically no spaces
        return s.contains(".") && !s.contains(" ")
    }

    private func executeFinder(_ r: DiskMapResolved) throws {
        // Directories → reveal in Finder
        if r.isDirectory {
            NSWorkspace.shared.activateFileViewerSelecting([r.absURL])
            return
        }

        // Files: "view" (reveal) vs "edit" (open in editor)
        let pref = cfg.finder?.default_action.file.lowercased() ?? "view"

        if pref == "edit" {
            if let editor = cfg.finder?.default_action.text_editor, !editor.isEmpty {
                if isLikelyBundleID(editor),
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: editor) {
                    // Use modern API to open with a specific application URL
                    let conf = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.open([r.absURL], withApplicationAt: appURL, configuration: conf) { _, error in
                        if let error { NSLog("[diskmap] open with \(editor) failed: \(error.localizedDescription)") }
                    }
                } else {
                    // Fallback: treat as display name (e.g., "TextEdit", "Sublime Text")
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    p.arguments = ["-a", editor, r.absURL.path]
                    try p.run()
                }
                return
            }

            // No specific editor configured → system default
            NSWorkspace.shared.open(r.absURL)
            return
        }

        // Default "view"
        NSWorkspace.shared.activateFileViewerSelecting([r.absURL])
    }

    private func executeTerminal(_ r: DiskMapResolved) throws {
        guard let termCfg = cfg.terminal else { throw DiskMapError.configMissingTerminal }

        // argv = ["nvim", "+17", "-Ex", "/abs/path"]
        let act: TerminalAction = r.isDirectory ? termCfg.default_action.directory
                                                : termCfg.default_action.file
        var argv: [String] = [act.use_command]
        if let line = r.line, !r.isDirectory { argv.append("+\(line)") }
        if let extra = act.arguments, !extra.isEmpty { argv.append(contentsOf: extra) }
        argv.append("--") // program separator
        argv.append(r.absURL.path)

        guard FileManager.default.fileExists(atPath: r.absURL.path) else {
            throw DiskMapError.launchFailed("Path does not exist: \(r.absURL.path)")
        }

        // If a terminal app is configured, route per-app
        if let appPathRaw = termCfg.terminal_application, !appPathRaw.isEmpty {
            let appURL = normalizeAppURL(appPathRaw)
            let appName = appURL.deletingPathExtension().lastPathComponent.lowercased()

            if appName.contains("terminal") || appName == "terminal" {
                // AppleScript ONLY for Terminal.app
                try runAppleScriptInTerminal(argv)
                return
            }

            if appName.contains("ghostty") {
                // Ghostty doesn’t support 'do script' → use LaunchServices
                try launchTerminalCLI(appPath: appURL.path, argv: argv)
                return
            }

            // Unknown terminal: try generic LaunchServices first
            try launchTerminalCLI(appPath: appURL.path, argv: argv)
            return
        }

        // No terminal configured → default to Terminal.app via AppleScript
        try runAppleScriptInTerminal(argv)
    }

    // ---------- Helpers ----------

    // Accept “…/Foo.app” or “…/Foo.app/Contents/MacOS/foo”
    private func normalizeAppURL(_ path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "app" { return url }
        return url
            .deletingLastPathComponent()    // MacOS
            .deletingLastPathComponent()    // Contents
            .deletingLastPathComponent()    // *.app
    }

    private func shellPath() -> String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    // POSIX single-quote (safe for spaces/specials)
    // a'b  ->  'a'\''b'
    private func shQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // func launchTerminalCLI(appPath: String, argv: [String]) throws {
    //     let p = Process()
    //     p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    //     p.arguments = ["-na", appPath, "--args", "-e"] + argv
    //     try p.run()
    // }

    func launchTerminalCLI(appPath: String, argv: [String]) throws {
        // Build the exact command you already intended, then hand it to a login shell
        let userCmd = argv.map(shQuote).joined(separator: " ")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-na", appPath, "--args", "-e",
                       shellPath(), "-l", "-c", userCmd]
        try p.run()
    }

    private func runAppleScriptInTerminal(_ argv: [String]) throws {
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
