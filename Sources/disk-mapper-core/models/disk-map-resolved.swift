import Foundation

public struct DiskMapResolved {
    public let action: DiskMapAction
    public let absURL: URL
    public let line: Int?
    public let isDirectory: Bool
}
