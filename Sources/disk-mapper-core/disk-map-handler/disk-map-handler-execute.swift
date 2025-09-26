import Foundation
import AppKit

extension DiskMapHandler {
    public func executeFinder(_ r: DiskMapResolved) throws {
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

    public func executeTerminal(_ r: DiskMapResolved) throws {
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
}
