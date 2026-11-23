import Darwin
import Foundation

/// Lists regular (Dock-visible) apps a user is running, without needing a window-server connection,
/// so it works from the root daemon.
enum RunningApps {
    struct App {
        var pid: pid_t
        var bundleID: String
    }

    private struct BundleInfo {
        var bundleID: String
        var executable: String
        var isRegular: Bool
    }

    nonisolated(unsafe) private static var cache: [String: BundleInfo?] = [:]

    static func list(uid: uid_t) -> [App] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let actual = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard actual > 0 else { return [] }

        var apps: [App] = []
        for pid in pids.prefix(Int(actual)) where pid > 0 {
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size, info.pbi_uid == uid else { continue }

            var buffer = [CChar](repeating: 0, count: 4096)
            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }
            let path = String(cString: buffer)

            // Main executables look like /…/Name.app/Contents/MacOS/Name
            guard let range = path.range(of: ".app/Contents/MacOS/", options: .backwards) else { continue }
            let bundlePath = String(path[..<range.lowerBound]) + ".app"
            let exe = String(path[range.upperBound...])
            guard let bundle = bundleInfo(bundlePath), bundle.isRegular, bundle.executable == exe else { continue }
            apps.append(App(pid: pid, bundleID: bundle.bundleID))
        }
        return apps
    }

    private static func bundleInfo(_ path: String) -> BundleInfo? {
        if let cached = cache[path] { return cached }
        var result: BundleInfo?
        if let plist = NSDictionary(contentsOfFile: path + "/Contents/Info.plist"),
           let id = plist["CFBundleIdentifier"] as? String {
            let exe = plist["CFBundleExecutable"] as? String ?? ""
            let uiElement = (plist["LSUIElement"] as? Bool) ?? ((plist["LSUIElement"] as? String) == "1")
            let backgroundOnly = (plist["LSBackgroundOnly"] as? Bool) ?? ((plist["LSBackgroundOnly"] as? String) == "1")
            result = BundleInfo(bundleID: id, executable: exe, isRegular: !uiElement && !backgroundOnly)
        }
        cache[path] = result
        return result
    }
}
