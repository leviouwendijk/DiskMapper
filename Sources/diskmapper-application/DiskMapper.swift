import SwiftUI
import DiskMapperCore
import plate

@main
struct DiskMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() } 
    } // optional
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep alive even with no windows (extra belt+suspenders)
        ProcessInfo.processInfo.disableAutomaticTermination("menu-bar-app")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "DiskMapper")
            button.image?.isTemplate = true // auto-dark/light
            button.toolTip = "DiskMapper"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open…", action: #selector(openWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DiskMapper", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handleDiskmap(url) }
    }

    private func handleDiskmap(_ url: URL) {
        guard url.scheme == "diskmap" else { return }

        do {
            // Load user config (~/dotfiles/disk-mapper/config.json or ~/disk-mapper/config.json)
            let cfg = try DiskMapConfig.load()
            let handler = DiskMapHandler(cfg: cfg)

            // Let the core parse diskmap://… (supports host action + ?rel=… or path segment)
            let resolved = try handler.resolve(url: url)

            // Execute (Finder reveal / system default / terminal per config)
            try handler.execute(resolved)

            NSLog("[DiskMapper] OK: \(url.absoluteString)")
        } catch {
            NSLog("[DiskMapper] ERROR handling \(url.absoluteString): \(error.localizedDescription)")
        }
    }

    // // Service entry point (Finder → Services → DiskMapper: Copy Link)
    // // Signature must match NSMessage in Info.plist (below).
    // @objc func copyDiskmapLink(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
    //     // Accept file URLs from Finder
    //     guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
    //         error.pointee = "No file URLs on pasteboard"
    //         return
    //     }

    //     // Build links (one per selection)
    //     let links: [String] = urls.map { url in
    //         // If DiskMapperCore exposes a resolver, use it here to turn absolute -> rel.
    //         // Example (replace with your real API):
    //         // let rel = DiskMapperCore.resolveRelativePath(for: url)
    //         // return DiskMapperCore.makeURL(rel: rel, action: nil, line: nil).absoluteString

    //         // Fallback: derive a 'rel' ourselves if you want:
    //         let rel = url.path // or your own project-root relative logic
    //         var comp = URLComponents()
    //         comp.scheme = "diskmap"
    //         comp.host = "" // force "diskmap://"
    //         comp.queryItems = [URLQueryItem(name: "rel", value: rel)]
    //         return comp.url!.absoluteString
    //     }

    //     let str = links.joined(separator: "\n")
    //     str.clipboard()
    // }

    @objc private func openWindow() {
        // present your UI/window here
    }

    @MainActor
    @objc private func openPrefs() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    @MainActor
    @objc private func quit() { NSApp.terminate(nil) }
}
