//
//  Process.swift
//  SelfControl
//
//  Created by Satendra Singh on 10/10/25.
//

import Foundation
import OSLog
import Security
import Darwin
import NetworkExtension

@objcMembers
class Process: NSObject {

    // MARK: - Properties (mirroring Process.h)

    dynamic var pid: pid_t = -1
    dynamic var uid: uid_t = UInt32(bitPattern: -1)
    dynamic var type: UInt16 = 0
    dynamic var exit: UInt32 = UInt32(bitPattern: -1)
    dynamic var deleted: Bool = false

    dynamic var name: String?
    dynamic var path: String?
    dynamic var arguments: NSMutableArray? = NSMutableArray()
    dynamic var ancestors: NSMutableArray? = NSMutableArray()
    dynamic var csInfo: NSMutableDictionary?
    dynamic var key: String = ""
    dynamic var bundleID: String = ""
    dynamic var binary: Binary = Binary.init("")
    dynamic var timestamp: Date = Date()

    // MARK: - Init

    override init() {
        super.init()
        self.arguments = NSMutableArray()
        self.ancestors = NSMutableArray()
        self.timestamp = Date()
        self.pid = -1
        self.uid = UInt32(bitPattern: -1)
        self.exit = UInt32(bitPattern: -1)
    }

    // Init with audit token pointer
    // Matches -(id)init:(audit_token_t*)token
    convenience init?(_ token: UnsafePointer<audit_token_t>) {
        self.init()

        // Save pid
        let tokenVal = token.pointee
        let procPID = audit_token_to_pid(tokenVal)
        self.pid = procPID
        if self.pid == 0 {
//            os_log_error(logHandle, "ERROR: 'audit_token_to_pid' returned NULL")
            return nil
        }

        // Get path via SecCode (also sets deleted flag)
        self.getPath(token)
        if (self.path ?? "").isEmpty {
//            os_log_error(logHandle, "ERROR: failed to find path for process %d", self.pid)
            return nil
        }

        // Set name
        if self.deleted != true {
            self.name = Utilities().getProcessName(0, self.path!)
        } else {
            self.name = Utilities().getProcessName(self.pid, self.path!)
        }

        // Get user
        self.uid = audit_token_to_euid(tokenVal)
        self.bundleID = Utilities().getBundleID(self.path ?? "") ?? ""
        // Generate (dynamic) code information
        self.generateSigningInfo(token)

        // Generate key
        self.key = self.generateKey()

        // Init binary
        self.binary = Binary(self.path ?? "")

        // PID specific logic: args and ancestors
        self.getArgs()
        self.ancestors = Utilities().generateProcessHierarchy(self.pid)

        // Verify pid-version (avoid pid reuse)
        if let currentTokenNSData = Utilities().tokenForPid(self.pid),
           currentTokenNSData.length == MemoryLayout<audit_token_t>.size {
            let currentTokenData = Data(referencing: currentTokenNSData)
            currentTokenData.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
                if let curPtr = rawPtr.baseAddress?.assumingMemoryBound(to: audit_token_t.self) {
                    let origVersion = audit_token_to_pidversion(tokenVal)
                    let curVersion = audit_token_to_pidversion(curPtr.pointee)
                    if origVersion != curVersion {
//                        os_log_error(logHandle, "ERROR: audit token mismatch ...pid re-used?")
                        self.arguments = nil
                        self.ancestors = nil
                    }
                }
            }
        }

        // Process alive check
        if Utilities().isAlive(self.pid) != true {
//            os_log_error(logHandle, "ERROR: process (%d)%{public}@ has already exited", self.pid, self.path ?? "")
            return nil
        }
    }

    // MARK: - Key generation

    // Matches -(NSString*)generateKey
    func generateKey() -> String {
        var id: String = ""
        var signer: Int = 0
        enum Signer: Int {
            case None = 0
            case Apple
            case AppStore
            case DevID
            case AdHoc
        }
        
        if let cs = self.csInfo {
            if let v = cs[Constants.KEY_CS_SIGNER] as? NSNumber {
                signer = v.intValue
            }

            // Apple/App Store: just use cs id
            if signer == Signer.Apple.rawValue || signer == Signer.AppStore.rawValue {
                if let csid = cs[Constants.KEY_CS_ID] as? String, !csid.isEmpty {
                    id = csid
                }
            }
            // Dev ID: use cs id + leaf signer
            else if signer == Int(Signer.DevID.rawValue) {
                if let csid = cs[Constants.KEY_CS_ID] as? String, !csid.isEmpty,
                   let auths = cs[Constants.KEY_CS_AUTHS] as? [Any], let first = auths.first as? String, !first.isEmpty {
                    id = "\(csid):\(first)"
                }
            }
        }

        if id.isEmpty {
            id = self.path ?? ""
        }

//        os_log_debug(logHandle, "generated process key: %{public}@", id)
        return id
    }

    // MARK: - Path

    // Matches -(void)getPath:(audit_token_t*)token
    func getPath(_ token: UnsafePointer<audit_token_t>) {
        var status: OSStatus = errSecParam
        var code: SecCode?
        var staticCode: SecStaticCode?
        var pathURL: CFURL?

        // SecCodeCopyGuestWithAttributes using audit token
        let attrs: [String: Any] = [kSecGuestAttributeAudit as String: Data(bytes: token, count: MemoryLayout<audit_token_t>.size)]
        status = SecCodeCopyGuestWithAttributes(nil, attrs as CFDictionary, SecCSFlags(), &code)
        if status == errSecSuccess, let code = code {
            // Convert dynamic code (SecCode) to static code (SecStaticCode)
            status = SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode)
            if status == errSecSuccess, let staticCode = staticCode {
                status = SecCodeCopyPath(staticCode, SecCSFlags(), &pathURL)
                if status == errSecSuccess, let url = pathURL as NSURL? {
                    self.path = (url as URL).path
                } else {
//                    os_log_error(logHandle, "ERROR: 'SecCodeCopyPath' failed with': %#x", status)
                }
            } else {
//                os_log_error(logHandle, "ERROR: 'SecCodeCopyStaticCode' failed with': %#x", status)
            }
        } else {
//            os_log_error(logHandle, "ERROR: 'SecCodeCopyGuestWithAttributes' failed with': %#x", status)
        }

        // Deleted binary?
        if status == OSStatus(kPOSIXErrorENOENT) {
//            os_log_debug(logHandle, "process %d's binary appears to be deleted", self.pid)
            self.deleted = true
        }

        // Fallback
        if pathURL == nil {
            self.path = Utilities().getProcessPath(self.pid)
        }

        if let p = self.path {
            self.path = (p as NSString).resolvingSymlinksInPath
        }

        // No CFRelease in Swift ARC; CoreFoundation objects are memory-managed automatically.
    }

    // MARK: - Args

    // Matches -(void)getArgs
    func getArgs() {
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX, 0]
        var systemMaxArgs: Int32 = 0
        var size = MemoryLayout.size(ofValue: systemMaxArgs)

        // Get system arg max
        if sysctl(&mib, 2, &systemMaxArgs, &size, nil, 0) == -1 {
            return
        }

        guard systemMaxArgs > 0 else { return }
        let bufSize = Int(systemMaxArgs)
        let processArgs = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        defer { processArgs.deallocate() }

        mib = [CTL_KERN, KERN_PROCARGS2, Int32(self.pid)]
        size = bufSize

        if sysctl(&mib, 3, processArgs, &size, nil, 0) == -1 {
            return
        }

        if size <= MemoryLayout<Int32>.size {
            return
        }

        // numberOfArgs at start
        var numberOfArgs: Int32 = 0
        memcpy(&numberOfArgs, processArgs, MemoryLayout<Int32>.size)

        // parser after numberOfArgs
        var parser = processArgs.advanced(by: MemoryLayout<Int32>.size)
        let endPtr = processArgs.advanced(by: size)

        // Skip executable path (NULL-terminated)
        while parser < endPtr {
            if parser.pointee == 0 { break }
            parser = parser.advanced(by: 1)
        }
        if parser == endPtr { return }

        // Skip trailing NULLs to argv[0]
        while parser < endPtr {
            if parser.pointee != 0 { break }
            parser = parser.advanced(by: 1)
        }
        if parser == endPtr { return }

        // Now parse args until count reached
        var argStart = parser
        let argsArray = NSMutableArray()
        while parser < endPtr {
            if parser.pointee == 0 {
                if let arg = String(validatingUTF8: UnsafePointer<CChar>(argStart)) {
                    argsArray.add(arg)
                }
                parser = parser.advanced(by: 1)
                argStart = parser
                if argsArray.count == Int(numberOfArgs) {
                    break
                }
                continue
            }
            parser = parser.advanced(by: 1)
        }

        self.arguments = argsArray
    }

    // MARK: - Code signing

    // Local key mapping for Security's kSecCodeInfoStatus
    private let KEY_CS_STATUS = "Status"

    // Helper to extract signing info from an audit token (dynamic code)
    private func extractSigningInfo(_ token: UnsafeMutablePointer<audit_token_t>,
                                    _ requirement: SecRequirement?,
                                    _ flags: SecCSFlags) -> NSMutableDictionary? {
        // Build attributes with audit token
        let attrs: [String: Any] = [kSecGuestAttributeAudit as String:
                                        Data(bytes: token, count: MemoryLayout<audit_token_t>.size)]
        var code: SecCode?
        var status = SecCodeCopyGuestWithAttributes(nil, attrs as CFDictionary, flags, &code)
        guard status == errSecSuccess, let codeRef = code else {
            return nil
        }

        // Convert SecCode (dynamic) to SecStaticCode before querying signing info
        var staticCode: SecStaticCode?
        status = SecCodeCopyStaticCode(codeRef, flags, &staticCode)
        guard status == errSecSuccess, let staticCodeRef = staticCode else {
            return nil
        }

        var info: CFDictionary?
        status = SecCodeCopySigningInformation(staticCodeRef, flags, &info)
        guard status == errSecSuccess, let dict = info as? [String: Any] else {
            return nil
        }
        return NSMutableDictionary(dictionary: dict)
    }

    // Matches -(void)generateSigningInfo:(audit_token_t*)token
    func generateSigningInfo(_ token: UnsafePointer<audit_token_t>) {
        // Pass typed nil for requirement to avoid "nil requires a contextual type"
        let requirement: SecRequirement? = nil
        if let extracted = extractSigningInfo(UnsafeMutablePointer(mutating: token), requirement, SecCSFlags()) {
            if let statusNum = extracted[KEY_CS_STATUS] as? NSNumber, statusNum.intValue == Int(noErr) {
                self.csInfo = extracted
            } else {
//                os_log_error(logHandle, "ERROR: invalid code signing information for %{public}@: %{public}@", self.path ?? "", extracted)
            }
        } else {
//            os_log_error(logHandle, "ERROR: failed to extract code signing information for %{public}@", self.path ?? "")
        }
    }

    // MARK: - Description

    override var description: String {
        return String(format: "pid: %d\npath: %@\nuser: %d\nargs: %@\nancestors: %@\n signing info: %@\n binary:\n%@", self.pid, self.path ?? "nil", self.uid, self.arguments ?? [], self.ancestors ?? [], self.csInfo ?? [:], self.binary.description)
    }
}

