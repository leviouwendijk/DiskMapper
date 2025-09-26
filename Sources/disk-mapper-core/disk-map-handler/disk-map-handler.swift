import Foundation
import AppKit

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

    // execute according to config
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
}
