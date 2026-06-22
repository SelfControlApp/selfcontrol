//
//  SafariExtensionMessages.swift
//  SelfControl
//
//  Created by Satendra Singh on 17/05/26.
//
import Foundation

enum ActiveBrowserExtensios: String {
    case safari
    case chrome
}


enum FlowInfoKey: String {
  case localPort
  case remoteAddress
}

/// App --> Provider IPC, to be implememted in Extension
///     // Use Objective-C bridgeable type for XPC surface
@objc public protocol AppToExtensionExtension {
    func register(_ completionHandler: @escaping (Bool) -> Void)
    func setBlockedURLs(_ urls: [String])
    func setActiveBrowserExtension(_ extensionTypeRawValue: String, state: Bool) //TODO: Remove once code is exported
    func setEnableService(_ enable: Bool)
}

/// Provider --> App IPC to Be implememted in the app
@objc public protocol ExtensionToApp {
  func promptUser(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void)
    func didSetUrls()
}
