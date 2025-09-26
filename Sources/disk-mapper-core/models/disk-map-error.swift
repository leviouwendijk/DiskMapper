import Foundation

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
