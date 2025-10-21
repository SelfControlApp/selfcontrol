//
//  File.swift
//  SelfControl
//
//  Created by Satendra Singh on 10/10/25.
//


//  Swift port of utilities.m
//
//  Note: This file relies on C system APIs. Ensure your bridging header
//  imports the needed headers: libproc.h, sys/sysctl.h, CommonCrypto/CommonCrypto.h,
//  mach/mach.h, Security/Security.h, Carbon/Carbon.h, CoreServices/CoreServices.h, CFNetwork/CFHost.h
//

import AppKit
import Foundation
import OSLog
import SystemConfiguration
import Darwin
import CoreServices // for MDItem
import Security
import os.log
import os

// Define C macro from libproc.h (not imported automatically into Swift)
private let PROC_PIDPATHINFO_MAXSIZE: Int = 4096

// MARK: - Globals

final class Utilities {
    // Provided elsewhere in project

    let logger = Logger(subsystem: "com.example.myapp", category: "network")

    // MARK: - Version / Bundle

    @objc
    public func getAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    @objc
    public func getBundleExecutable(_ appPath: String) -> String? {
        guard let bundle = Bundle(path: appPath) else {
            logger.error("ERROR: failed to load app bundle for %{public}\(appPath)")
            return nil
        }
        return (bundle.executablePath as NSString?)?.resolvingSymlinksInPath
    }

    // MARK: - Parent process (Carbon/deprecated)

    @objc
    public func getRealParent(_ pid: pid_t) -> NSDictionary? {
        let PROC_PIDPATHINFO_MAXSIZE = 4096

        // Step 1: Get parent PID
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
            return nil
        }

        let ppid = info.kp_eproc.e_ppid
        if ppid == 0 { return nil }

        // Step 2: Get parent process path
        var pathBuffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let result = proc_pidpath(ppid, &pathBuffer, UInt32(pathBuffer.count))
        let path = (result > 0) ? String(cString: pathBuffer) : nil

        // Step 3: Try to get bundle info via NSRunningApplication
        var appName: String? = nil
        var bundleID: String? = nil

        if let app = NSRunningApplication(processIdentifier: ppid) {
            appName = app.localizedName
            bundleID = app.bundleIdentifier
        }

        // Step 4: Construct NSDictionary for compatibility
        let dict: NSDictionary = [
            "ParentPID": NSNumber(value: ppid),
            "ParentPath": path ?? "",
            "ParentAppName": appName ?? "",
            "ParentBundleID": bundleID ?? ""
        ]

        return dict
    }


    // MARK: - Process hierarchy

    @objc
    public func generateProcessHierarchy(_ child: pid_t) -> NSMutableArray {
        let ancestors = NSMutableArray()
        typealias RPIDFunc = @convention(c) (pid_t) -> pid_t
        let rpidSym = dlsym(dlopen(nil, RTLD_NOW), "responsibility_get_pid_responsible_for_pid")
        let getRPID = rpidSym.map { unsafeBitCast($0, to: RPIDFunc.self) }

        var currentPID = child

        while true {
            let currentPath = getProcessPath(currentPID) ?? NSLocalizedString("unknown", comment: "unknown")
            let currentName = getProcessName(0, currentPath) ?? NSLocalizedString("unknown", comment: "unknown")
            ancestors.insert([
                Constants.KEY_PROCESS_ID: NSNumber(value: currentPID),
                Constants.KEY_PROCESS_PATH: currentPath,
                Constants.KEY_PROCESS_NAME: currentName
            ], at: 0)

            var parentPID: pid_t = 0

            if getuid() != 0 {
                if let parent = getRealParent(currentPID), let p = parent["pid"] as? NSNumber {
                    parentPID = pid_t(truncating: p)
                }
            }

            if parentPID == 0, let getRPID = getRPID {
                parentPID = getRPID(currentPID)
            }

            if parentPID <= 0 || parentPID == currentPID {
                parentPID = getParent(Int32(currentPID))
            }

            if parentPID <= 0 || parentPID == currentPID {
                break
            }

            currentPID = parentPID
        }

        // add KEY_INDEX for UI
        for i in 0..<ancestors.count {
            if var dict = ancestors[i] as? [String: Any] {
                dict[Constants.KEY_INDEX] = NSNumber(value: i)
                ancestors[i] = dict
            }
        }

        return ancestors
    }

    // MARK: - Console user

    @objc
    public func getConsoleUser() -> String? {
        var uid: uid_t = 0
        var gid: gid_t = 0
        
        // explicitly type `nil` as `SCDynamicStore?`
        if let cfUser = SCDynamicStoreCopyConsoleUser(nil as SCDynamicStore?, &uid, &gid) {
            return cfUser as String
        }
        return nil
    }

    // MARK: - Process name

    @objc
    public func getProcessName(_ pid: pid_t, _ path: String) -> String? {

        let PROC_PIDPATHINFO_MAXSIZE = 4096 // actual constant value from libproc.h

        if pid != 0 {
            var nameBuf = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
            let status = proc_name(pid, &nameBuf, UInt32(nameBuf.count))
            if status >= 0 {
                return String(cString: nameBuf)
            }
        }

        if let bundle = findAppBundle(path),
           let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }

        return (path as NSString).lastPathComponent
    }

    @objc
    public func getBundleID(_ path: String) -> String? {
        if let bundle = findAppBundle(path),
           let name = bundle.infoDictionary?["CFBundleIdentifier"] as? String {
            return name
        }
        return nil
    }
    
    // MARK: - Find app bundle

    @objc
    public func findAppBundle(_ path: String) -> Bundle? {
        let standardized = ((path as NSString).standardizingPath as NSString).resolvingSymlinksInPath
        var appPath: NSString = standardized as NSString

        while true {
            if let bundle = Bundle(path: appPath as String) {
                if bundle.bundlePath == standardized { return bundle }
                if bundle.executablePath == standardized { return bundle }
            }

            let next = appPath.deletingLastPathComponent as NSString
            if next.length == 0 || next as String == "/" { break }
            appPath = next
        }

        return nil
    }

    // MARK: - Process path

    @objc
    public func getProcessPath(_ pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let status = proc_pidpath(pid, &buf, UInt32(buf.count))
        if status > 0 {
            return String(cString: buf)
        } else {
//            os_log_error(logHandle, "ERROR: for process %d, 'proc_pidpath' failed with %d (errno: %d)", pid, status, errno)

            var mib = [CTL_KERN, KERN_ARGMAX, 0]
            var argMax: Int = 0
            var size = MemoryLayout.size(ofValue: argMax)
            if sysctl(&mib, 2, &argMax, &size, nil, 0) == -1 { return nil }

            let argBuf = UnsafeMutablePointer<CChar>.allocate(capacity: argMax)
            defer { argBuf.deallocate() }

            mib = [CTL_KERN, KERN_PROCARGS2, Int32(pid)]
            size = argMax
            if sysctl(&mib, 3, argBuf, &size, nil, 0) == -1 { return nil }
            if size <= MemoryLayout<Int32>.size { return nil }

            // argv0 path follows int argc
            let pathPtr = argBuf.advanced(by: MemoryLayout<Int32>.size)
            let p = String(cString: pathPtr)

            if p.hasPrefix("./") {
                let trimmed = String(p.dropFirst(2))
                if let cwd = getProcessCWD(pid) {
                    return (cwd as NSString).appendingPathComponent(trimmed)
                }
            }

            return p
        }
    }

    // MARK: - CWD

    @objc
    public func getProcessCWD(_ pid: pid_t) -> String? {
        var vpi = proc_vnodepathinfo()
        let status = withUnsafeMutablePointer(to: &vpi) { ptr -> Int32 in
            return proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, ptr, Int32(MemoryLayout<proc_vnodepathinfo>.size))
        }
        if status > 0 {
            return withUnsafePointer(to: vpi.pvi_cdir.vip_path) { ptr in
                return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
            }
        }
        return nil
    }

    // MARK: - PIDs for path/user

    @objc
    public func getProcessIDs(_ processPath: String, _ userID: Int32) -> NSMutableArray {
        let result = NSMutableArray()

        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return result }

        let pids = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(count))
        defer { pids.deallocate() }

        let status = proc_listallpids(pids, count * Int32(MemoryLayout<pid_t>.size))
        guard status >= 0 else { return result }

        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, 0]
        var kproc = kinfo_proc()
        let kprocSize = MemoryLayout<kinfo_proc>.size

        for i in 0..<Int(count) {
            let p = pids[i]
            if p == 0 { continue }
            if getProcessPath(p) != processPath { continue }

            if userID != -1 {
                mib[3] = Int32(p)
                var size = kprocSize
                if sysctl(&mib, 4, &kproc, &size, nil, 0) != 0 || size == 0 {
                    continue
                }
                if Int32(kproc.kp_eproc.e_ucred.cr_uid) != userID {
                    continue
                }
            }

            result.add(NSNumber(value: p))
        }

        return result
    }

    // MARK: - Toggle menu

    @objc
    public func toggleMenu(_ menu: NSMenu, _ shouldEnable: Bool) {
        menu.autoenablesItems = false
        for item in menu.items {
            item.isEnabled = shouldEnable
        }
    }

    // MARK: - Icon for process

    @objc
    public func getIconForProcess(_ path: String) -> NSImage? {
        // invalid path -> generic application icon
        guard FileManager.default.fileExists(atPath: path) else {
            let icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
            icon.size = NSSize(width: 128, height: 128)
            return icon
        }

        if let bundle = findAppBundle(path) {
            if let icon = NSWorkspace.shared.icon(forFile: bundle.bundlePath) as NSImage? {
                return icon
            }

            if let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? NSString {
                var ext = iconFile.pathExtension
                if ext.isEmpty { ext = "icns" }
                if let iconPath = bundle.path(forResource: iconFile.deletingPathExtension, ofType: ext) {
                    return NSImage(contentsOfFile: iconPath)
                }
            }
        }

        var icon = NSWorkspace.shared.icon(forFile: path)
        // replace generic document icon with application icon
        let documentIcon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericDocumentIcon)))
        if icon == documentIcon {
            icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
        }
        icon.size = NSSize(width: 128, height: 128)
        return icon
    }

    // MARK: - Make modal

    @objc
    public func makeModal(_ controller: NSWindowController) {
        var window: NSWindow?

        for _ in 0..<20 {
            DispatchQueue.main.sync {
                window = controller.window
            }
            if window == nil {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            DispatchQueue.main.sync {
                NSApplication.shared.runModal(for: controller.window!)
            }
            break
        }
    }

    // MARK: - Find processes by name

    @objc
    public func findProcesses(_ processName: String) -> NSMutableArray {
        let processes = NSMutableArray()
        let count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard count > 0 else { return processes }

        let pids = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(count))
        defer { pids.deallocate() }

        let status = proc_listpids(UInt32(PROC_ALL_PIDS), 0, pids, count * Int32(MemoryLayout<pid_t>.size))
        guard status >= 0 else { return processes }

        for i in 0..<Int(count) {
            let p = pids[i]
            if p == 0 { continue }
            guard let path = getProcessPath(p), !path.isEmpty else { continue }
            if (path as NSString).lastPathComponent == processName {
                processes.add([Constants.KEY_PROCESS_ID: NSNumber(value: p), Constants.KEY_PATH: path])
            }
        }

        return processes
    }

//    // MARK: - Spotlight date added
//
//    @objc
//    public func dateAdded(_ file: String) -> Date? {
//        os_log_debug(logHandle, "extracting 'kMDItemDateAdded' for %{public}@", file)
//
//        let url: URL
//        if let bundle = findAppBundle(file) {
//            url = bundle.bundleURL
//        } else {
//            url = URL(fileURLWithPath: file)
//        }
//
//        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
//        defer { CFRelease(item) }
//
//        if let date = MDItemCopyAttribute(item, kMDItemDateAdded)?.takeRetainedValue() as? Date {
//            os_log_debug(logHandle, "extacted date, %{public}@, for %{public}@", String(describing: date), file)
//            return date
//        } else {
//            os_log_debug(logHandle, "'kMDItemDateAdded' is nil ...falling back to 'kMDItemFSCreationDate'")
//            if let date = MDItemCopyAttribute(item, kMDItemFSCreationDate)?.takeRetainedValue() as? Date {
//                os_log_debug(logHandle, "extacted date, %{public}@, for %{public}@", String(describing: date), file)
//                return date
//            }
//        }
//        return nil
//    }

    // MARK: - Parent PID

    @objc
    public func getParent(_ pid: Int32) -> pid_t {
        var kproc = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid] // 👈 consistent Int32s
        let res = sysctl(&mib, u_int(mib.count), &kproc, &size, nil, 0)
        if res == 0 && size != 0 {
            let ppid = kproc.kp_eproc.e_ppid
//            os_log_debug(logHandle, "extracted parent ID %d for process: %d", ppid, pid)
            return ppid
        }
        return -1
    }

    // MARK: - Dark mode

    @objc
    public func isDarkMode() -> Bool {
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    // MARK: - String default

    @objc
    public func valueForStringItem(_ item: String?) -> String {
        return item ?? NSLocalizedString("unknown", comment: "unknown")
    }

    // MARK: - Alerts

    @objc
    public func showAlert(_ style: NSAlert.Style, _ messageText: String, _ informativeText: String?, _ buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = messageText
        if let info = informativeText {
            alert.informativeText = info
        }
        for title in buttons {
            alert.addButton(withTitle: title)
        }
        if let first = alert.buttons.first {
            first.keyEquivalent = "\r"
        }

        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        alert.window.makeKeyAndOrderFront(nil)
        alert.window.center()

        let response = alert.runModal()
//        (NSApp.delegate as? AppDelegate)?.setActivationPolicy()
        return response
    }

    // MARK: - Audit token for pid

    // Swift doesn't expose this C macro — we define it manually.
    let TASK_AUDIT_TOKEN_COUNT = mach_msg_type_number_t(MemoryLayout<audit_token_t>.size / MemoryLayout<natural_t>.size)

    @objc
    public func tokenForPid(_ pid: pid_t) -> NSData? {
        var task: mach_port_t = 0
        var token = audit_token_t()
        var size = TASK_AUDIT_TOKEN_COUNT

//        os_log_debug(logHandle, "retrieving audit token for %d", pid)

        var kr = task_name_for_pid(mach_task_self_, pid, &task)
        guard kr == KERN_SUCCESS else {
//            os_log_error(logHandle, "ERROR: 'task_name_for_pid' failed with %x", kr)
            return nil
        }
        defer { mach_port_deallocate(mach_task_self_, task) }

        kr = withUnsafeMutablePointer(to: &token) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                return task_info(task, task_flavor_t(TASK_AUDIT_TOKEN), intPtr, &size)
            }
        }

        guard kr == KERN_SUCCESS else {
//            os_log_error(logHandle, "ERROR: 'task_info' failed with %x", kr)
            return nil
        }

//        os_log_debug(logHandle, "retrieved audit token")
        return NSData(bytes: &token, length: MemoryLayout<audit_token_t>.size)
    }

    // MARK: - Reverse DNS resolve

    @objc
    public func resolveAddress(_ ipAddr: String) -> NSArray? {
//        os_log_debug(logHandle, "(attempting to) reverse resolve %{public}@", ipAddr)

        var hints = addrinfo(ai_flags: AI_NUMERICHOST, ai_family: PF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(ipAddr, nil, &hints, &res) == 0, let result = res else {
            return nil
        }
        defer { freeaddrinfo(result) }

        guard let addrData = CFDataCreate(nil, UnsafePointer<UInt8>(OpaquePointer(result.pointee.ai_addr)), CFIndex(result.pointee.ai_addrlen)) else {
            return nil
        }
        defer { /*addrData*/ }

        let host = CFHostCreateWithAddress(kCFAllocatorDefault, addrData).takeRetainedValue()
        var streamErr = CFStreamError()
        guard CFHostStartInfoResolution(host, .names, &streamErr) else {
            return nil
        }
        guard let names = CFHostGetNames(host, nil)?.takeUnretainedValue() as NSArray? else {
            return nil
        }
        return names
    }

    // MARK: - Process alive

    @objc
    public func isAlive(_ processID: pid_t) -> Bool {
        errno = 0
        _ = kill(processID, 0)
        if errno == ESRCH { return false }

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(processID)]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        if sysctl(&mib, 4, &info, &size, nil, 0) == 0 {
            // SZOMB check
            if (UInt8(info.kp_proc.p_stat) & UInt8(SZOMB)) == UInt8(SZOMB) {
                return false
            }
        }
        return true
    }

    // MARK: - Simulator app?

    @objc
    public func isSimulatorApp(_ path: String) -> Bool {
//        os_log_debug(logHandle, "checking if %{public}@ is a simulator application", path)
        guard let bundle = findAppBundle(path) else { return false }
        guard let platforms = bundle.infoDictionary?["CFBundleSupportedPlatforms"] as? [String], !platforms.isEmpty else {
            return false
        }
//        os_log_debug(logHandle, "supported platforms: %{public}@", String(describing: platforms))
        let set = Set(platforms)
        return set.isSubset(of: Set(["iPhoneSimulator", "AppleTVSimulator"]))
    }

    // MARK: - Launched by user?

    @objc
    public func launchedByUser() -> Bool {
        guard let parent = getRealParent(getpid()) else { return false }
        let bid = parent["CFBundleIdentifier"] as? NSString
        if bid == "com.apple.dock" || bid == "com.apple.finder" || bid == "com.apple.Terminal" {
            return true
        }
        return false
    }

    // MARK: - Fade out

    @objc
    public func fadeOut(_ window: NSWindow, _ duration: Float) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = TimeInterval(duration)
            window.animator().alphaValue = 0.0
        } completionHandler: {
            window.close()
        }
    }

    // MARK: - Code-signing info match

//    @objc
//    public func matchesCSInfo(_ csInfo1: NSDictionary?, _ csInfo2: NSDictionary?) -> Bool {
//        var status1 = -1, status2 = -1
//        var signer1 = -1, signer2 = -1
//        var id1: String?, id2: String?
//        var auths1: [Any]?, auths2: [Any]?
//
//        if let n = csInfo1?[KEY_CS_STATUS] as? NSNumber { status1 = n.intValue }
//        if let n = csInfo2?[KEY_CS_STATUS] as? NSNumber { status2 = n.intValue }
//        if status1 != status2 {
//            os_log_error(logHandle, "ERROR: code signing mismatch (signing status): %{public}@ / %{public}@", String(describing: csInfo1), String(describing: csInfo2))
//            return false
//        }
//
//        if let n = csInfo1?[KEY_CS_SIGNER] as? NSNumber { signer1 = n.intValue }
//        if let n = csInfo2?[KEY_CS_SIGNER] as? NSNumber { signer2 = n.intValue }
//        if signer1 != signer2 {
//            if (signer1 == Apple && signer2 == AppStore) || (signer1 == AppStore && signer2 == Apple) {
//                os_log_error(logHandle, "ignoring case where Apple App moved to/from Mac App Store: %{public}@ / %{public}@", String(describing: csInfo1), String(describing: csInfo2))
//            } else {
//                os_log_error(logHandle, "ERROR: code signing mismatch (signer): %{public}@ / %{public}@", String(describing: csInfo1), String(describing: csInfo2))
//                return false
//            }
//        }
//
//        if let s = csInfo1?[KEY_CS_ID] as? String { id1 = s }
//        if let s = csInfo2?[KEY_CS_ID] as? String { id2 = s }
//        if (id1 != nil || id2 != nil), id1 != id2 {
//            os_log_error(logHandle, "ERROR: code signing mismatch (signing ID): %{public}@ / %{public}@", String(describing: csInfo1), String(describing: csInfo2))
//            return false
//        }
//
//        if let a = csInfo1?[KEY_CS_AUTHS] as? [Any] { auths1 = a }
//        if let a = csInfo2?[KEY_CS_AUTHS] as? [Any] { auths2 = a }
//        if (auths1 != nil || auths2 != nil) && !(auths1 as NSArray? ?? []).isEqual(to: auths2 ?? []) {
//            os_log_error(logHandle, "ERROR: code signing mismatch (signing auths): %{public}@ / %{public}@", String(describing: csInfo1), String(describing: csInfo2))
//            return false
//        }
//
//        return true
//    }

    // MARK: - Escape JSON

    @objc
    public func toEscapedJSON(_ input: String) -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: input, options: .fragmentsAllowed)
            return String(data: data, encoding: .utf8)
        } catch {
//            os_log_error(logHandle, "ERROR: failed to convert/escape %{public}@ to JSON (error: %{public}@)", input, error.localizedDescription)
            return nil
        }
    }

    // MARK: - Absolute date from HH:mm (next 24h)

    @objc
    public func absoluteDate(_ date: Date) -> Date {
//        os_log_debug(logHandle, "function '%{public}s' invoked with %{public}@", #function, String(describing: date))

        let now = Date()
        let cal = Calendar.current

        let comps = cal.dateComponents([.hour, .minute], from: date)
        var nowComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        nowComps.hour = comps.hour
        nowComps.minute = comps.minute

        var absDate = cal.date(from: nowComps) ?? now
        if absDate < now {
            absDate = cal.date(byAdding: .day, value: 1, to: absDate) ?? absDate
        }
        return absDate
    }

    // MARK: - Internal volume?

    @objc
    public func isInternalProcess(_ path: String) -> Bool {
        var isInternal: AnyObject?
        do {
            var url = URL(fileURLWithPath: path)
            try (url as NSURL).getResourceValue(&isInternal, forKey: URLResourceKey.volumeIsInternalKey)
            return (isInternal as? NSNumber)?.boolValue ?? false
        } catch {
//            os_log_error(logHandle, "ERROR: 'getResourceValue'/'NSURLVolumeIsInternalKey' failed with %@", error.localizedDescription)
            return false
        }
    }


}

