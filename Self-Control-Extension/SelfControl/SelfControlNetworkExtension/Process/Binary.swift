//
//  Binary.swift
//  SelfControl
//
//  Created by Satendra Singh on 10/10/25.
//

import Foundation
import AppKit
import OSLog
import Security
import CoreServices // for MDItem

@objcMembers
class Binary: NSObject {

    // MARK: - Properties (mirroring Binary.h)

    dynamic var path: String
    dynamic var name: String = ""
    dynamic var icon: NSImage = NSImage()
    dynamic var attributes: NSDictionary?
    dynamic var metadata: NSDictionary?
    dynamic var bundle: Bundle?
    dynamic var csInfo: NSMutableDictionary = NSMutableDictionary()
    dynamic var sha256: NSMutableString = NSMutableString()

    // MARK: - Init

    init(_ path: String) {
        self.path = (path as NSString).resolvingSymlinksInPath
        super.init()

        // Try load app bundle (nil for non-apps)
        self.getBundle()

        // Get name
        self.getName()

        // File attributes
        self.getAttributes()

        // Spotlight metadata
        self.getMetadata()
    }

    // MARK: - Bundle

    // Try load app bundle; nil for non-apps
    func getBundle() {
        // First try direct path
        if let b = Bundle(path: self.path) {
            self.bundle = b
            return
        }
        // Else find dynamically
        self.bundle = Utilities().findAppBundle(self.path)
    }

    // MARK: - Name

    // Figure out binary's name via bundle CFBundleName or lastPathComponent
    func getName() {
        if let bundle = self.bundle,
           let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
            self.name = bundleName
        } else {
            self.name = (self.path as NSString).lastPathComponent
        }
    }

    // MARK: - Attributes

    func getAttributes() {
        self.attributes = try? FileManager.default.attributesOfItem(atPath: self.path) as NSDictionary
    }

    // MARK: - Spotlight metadata

    func getMetadata() {
        // MDItemCreate wants CFString path
        let cfPath = self.path as CFString
        guard let mdItem = MDItemCreate(kCFAllocatorDefault, cfPath) else {
            return
        }
        defer { }

        guard let attributeNames = MDItemCopyAttributeNames(mdItem) else {
            return
        }
        defer { }

        if let attrs = MDItemCopyAttributes(mdItem, attributeNames) {
            self.metadata = attrs as NSDictionary
        }
    }

    // MARK: - Icon

    // Get an icon for the process: app’s icon or system one
    func getIcon() {
        // Skip short/non-absolute paths if no bundle (system logs errors otherwise)
        if !self.path.hasPrefix("/"), self.bundle == nil {
            return
        }

        // For apps, try CFBundleIconFile
        if let bundle = self.bundle {
            if let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? String {
                let iconExt = (iconFile as NSString).pathExtension.isEmpty ? "icns" : (iconFile as NSString).pathExtension
                let iconBase = (iconFile as NSString).deletingPathExtension
                if let iconPath = bundle.path(forResource: iconBase, ofType: iconExt) {
                    if let img = NSImage(contentsOfFile: iconPath) {
                        self.icon = img
                    }
                }
            }
        }

        // Fallback to workspace icon
        if self.bundle == nil || self.icon.size == .zero {
            self.icon = NSWorkspace.shared.icon(forFile: self.path)
        }

        // Standard size 128x128
        self.icon.size = NSSize(width: 128, height: 128)
    }

    // MARK: - Code signing (static)

    // You likely have this helper already, but defining its expected signature for clarity:
    func extractSigningInfo(_ code: SecStaticCode?, _ path: String, _ flags: SecCSFlags) -> [String: Any]? {
        var staticCode: SecStaticCode?
        let url = URL(fileURLWithPath: path) as CFURL
        let status = SecStaticCodeCreateWithPath(url, SecCSFlags(), &staticCode)
        guard status == errSecSuccess, let codeRef = staticCode else {
            return nil
        }

        var signingInfo: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(codeRef, flags, &signingInfo)
        guard infoStatus == errSecSuccess, let info = signingInfo as? [String: Any] else {
            return nil
        }
        return info
    }

    // Your corrected function:
    func generateSigningInfo(_ flags: SecCSFlags) {
        // These constants are C macros in Security framework headers, not imported automatically:
        let kSecCodeInfoStatus = "Status"        // corresponds to kSecCodeInfoStatus in Security framework
        let KEY_CS_STATUS = kSecCodeInfoStatus   // for compatibility with your existing code

        // Instead of 'nil', explicitly pass an optional SecStaticCode? = nil
        if let extracted = extractSigningInfo(nil as SecStaticCode?, self.path, flags),
           let statusNum = extracted[KEY_CS_STATUS] as? NSNumber,
           statusNum.intValue == Int(noErr) {
            // Bridge [String: Any] to NSMutableDictionary
            self.csInfo = NSMutableDictionary(dictionary: extracted)
        } else {
            // logging commented out in original code
        }
    }

    // MARK: - Description

    override var description: String {
        return String(format: "name: %@\npath: %@\nattributes: %@\nsigning info: %@\nmetadata: %@",
                      self.name,
                      self.path,
                      self.attributes ?? [:],
                      self.csInfo,
                      self.metadata ?? [:])
    }
}
