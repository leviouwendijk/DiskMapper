import Foundation
import AppKit
import ArgumentParser
import DiskMapperCore

// CLI supports either:
//   diskmap 'diskmap://terminal?rel=path/to/file.swift&line=42' [--dry-run]
// or:
//   diskmap terminal|finder|system_default RELPATH [--line N] [--dry-run]

struct ProcessURL: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "process",
        abstract: "Open project-relative paths via a stable, shareable diskmap:// URL."
    )

    @Flag(help: "Resolve and print, but do not open.")
    var dryRun: Bool = false

    @Option(name: .long, help: "Full diskmap:// URL (overrides positional args).")
    var url: String?

    @Argument(help: "Action when not using --url (terminal | finder | system_default).", transform: { $0.lowercased() })
    var action: String?

    @Argument(help: "Relative path from configured project root (ignored if --url is used).")
    var rel: String?

    @Option(name: .customLong("line"), parsing: .unconditional, help: "Optional line number (files only).")
    var line: Int?

    func run() throws {
        let cfg = try DiskMapConfig.load()
        let handler = DiskMapHandler(cfg: cfg)

        let targetURL: URL = try makeURL()
        let resolved = try handler.resolve(url: targetURL)

        if dryRun {
            let t = resolved.isDirectory ? "dir" : "file"
            print("DRY-RUN action=\(resolved.action) type=\(t) abs=\(resolved.absURL.path) line=\(resolved.line ?? -1)")
        } else {
            try handler.execute(resolved)
        }
    }

    private func makeURL() throws -> URL {
        if let urlStr = url, let u = URL(string: urlStr), u.scheme == "diskmap" {
            return u
        }
        guard let action, let rel else {
            throw ValidationError("Provide --url 'diskmap://…' or positional: <action> <rel> [--line N]")
        }
        var comp = URLComponents()
        comp.scheme = "diskmap"
        comp.host = action
        comp.queryItems = [URLQueryItem(name: "rel", value: rel)]
        if let line { comp.queryItems?.append(URLQueryItem(name: "line", value: String(line))) }
        guard let u = comp.url else { throw ValidationError("Could not construct diskmap URL") }
        return u
    }
}
