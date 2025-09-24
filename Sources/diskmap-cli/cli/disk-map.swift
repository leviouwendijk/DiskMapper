import Foundation
import ArgumentParser
import DiskMapperCore

struct DiskMap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diskmap",
        abstract: "get and parse links for filesys",
        subcommands: [ProcessURL.self, GetLink.self],
        defaultSubcommand: ProcessURL.self
    )
}
