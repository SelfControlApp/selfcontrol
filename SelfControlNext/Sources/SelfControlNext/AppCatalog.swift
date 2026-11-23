import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// Installed applications, for the app pickers.
@MainActor @Observable
final class AppCatalog {
    static let shared = AppCatalog()

    private(set) var apps: [AppRef] = []
    private(set) var isLoaded = false
    @ObservationIgnored private var loading = false

    func loadIfNeeded() {
        guard !isLoaded, !loading else { return }
        loading = true
        Task {
            let found = await Task.detached(priority: .userInitiated) { Self.scan() }.value
            apps = found
            isLoaded = true
            loading = false
        }
    }

    nonisolated private static func scan() -> [AppRef] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let roots = ["/Applications", "/Applications/Utilities", "/System/Applications",
                     "/System/Applications/Utilities", "\(home)/Applications"]
        var seen = Set<String>()
        var result: [AppRef] = []

        func add(_ url: URL) {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, !seen.contains(id),
                  id != Store.ownBundleID else { return }
            seen.insert(id)
            let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? fm.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            result.append(AppRef(bundleID: id, name: name, path: url.path))
        }

        for root in roots {
            guard let items = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil) else { continue }
            for item in items {
                if item.pathExtension == "app" {
                    add(item)
                } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                          let nested = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                    nested.filter { $0.pathExtension == "app" }.forEach(add)
                }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Icons

    @ObservationIgnored private var iconCache: [String: NSImage] = [:]

    func icon(for app: AppRef) -> NSImage {
        if let cached = iconCache[app.bundleID] { return cached }
        let path = app.path.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)?.path
        let image = path.map { NSWorkspace.shared.icon(forFile: $0) }
            ?? NSWorkspace.shared.icon(for: .application)
        iconCache[app.bundleID] = image
        return image
    }

    /// Lets the user pick any .app with an open panel.
    static func chooseAppWithOpenPanel() -> AppRef? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return AppRef(bundleID: id, name: name, path: url.path)
    }
}

struct AppIconView: View {
    let app: AppRef
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: AppCatalog.shared.icon(for: app))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}
