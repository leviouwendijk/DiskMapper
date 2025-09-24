import Foundation
import ArgumentParser
import DiskMapperCore
import plate

struct GetLink: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Generate a diskmap:// link for a relative path"
    )

    @Argument(help: "Relative path from project root")
    var rel: String

    @Option(name: .customLong("action"), help: "Override action (terminal | finder | system_default)")
    var action: String?

    @Option(name: .customLong("line"), parsing: .unconditional, help: "Optional line number (files only).")
    var line: Int?

    @Flag(name: .customLong("nc"), help: "Override copying to clipboard.")
    var noCopy: Bool = false

    private var copy: Bool {
        return !noCopy
    }

    // func run() throws {
    //     // Build diskmap:// URL
    //     var comp = URLComponents()
    //     comp.scheme = "diskmap"
    //     comp.host = (action?.isEmpty == false) ? action : ""   // ← force // when no action
    //     comp.queryItems = [URLQueryItem(name: "rel", value: rel)]
    //     if let line {
    //         comp.queryItems?.append(URLQueryItem(name: "line", value: String(line)))
    //     }
    //     guard let u = comp.url else { throw ValidationError("Could not build URL") }

    //     // Existence check (supports absolute, relative, and ~)
    //     let fm = FileManager.default
    //     let expanded = (rel as NSString).expandingTildeInPath
    //     let full: URL
    //     if (expanded as NSString).isAbsolutePath {
    //         full = URL(fileURLWithPath: expanded).standardizedFileURL
    //     } else {
    //         let base = URL(fileURLWithPath: fm.currentDirectoryPath)
    //         full = URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL
    //     }

    //     var isDir: ObjCBool = false
    //     if !fm.fileExists(atPath: full.path, isDirectory: &isDir) {
    //         FileHandle.standardError.write(Data("warning: path does not exist: \(rel) (resolved: \(full.path))\n".utf8))
    //     } else {
    //         if copy {
    //             u.absoluteString.clipboard()
    //         }
    //     }

    //     print(u.absoluteString) // now "diskmap://?rel=…" or "diskmap://finder?rel=…"
    // }

    func run() throws {
        // Load config (for root + rules) and build a handler so we can compute rel
        let cfg = try DiskMapConfig.load()
        let handler = DiskMapHandler(cfg: cfg)

        // 1) Normalize input path: allow abs / ~ / rel
        let fm = FileManager.default
        let expanded = (rel as NSString).expandingTildeInPath
        let absURL: URL = {
            if (expanded as NSString).isAbsolutePath {
                return URL(fileURLWithPath: expanded).standardizedFileURL
            } else {
                let base = URL(fileURLWithPath: fm.currentDirectoryPath)
                return URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL
            }
        }()

        // 2) If it's under cfg.root, convert to project-relative; else error
        let relPath: String
        do {
            relPath = try handler.relativePath(fromAbs: absURL)
        } catch {
            throw ValidationError("Path is outside the configured root: \(absURL.path)")
        }

        // 3) Build the diskmap:// URL (host only when --action is set)
        let u = makeDiskmapURL(rel: relPath, action: action, line: line)

        // 4) Existence warning (same behavior as before)
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: absURL.path, isDirectory: &isDir) {
            FileHandle.standardError.write(Data("warning: path does not exist: \(rel) (resolved: \(absURL.path))\n".utf8))
        }

        // 5) Copy to clipboard unless --nc
        if !noCopy { u.absoluteString.clipboard() }

        // 6) Always print the link
        print(u.absoluteString)
    }

    private func makeDiskmapURL(rel: String, action: String?, line: Int?) -> URL {
        var comp = URLComponents()
        comp.scheme = "diskmap"
        comp.host = (action?.isEmpty == false) ? action : ""   // hostless when nil/empty
        var items = [URLQueryItem(name: "rel", value: rel)]
        if let line { items.append(URLQueryItem(name: "line", value: String(line))) }
        comp.queryItems = items
        // This should never fail with the inputs we provide; force unwrap is fine here.
        return comp.url!
    }
}
