//
//  SCUIUtility.swift
//  SelfControl
//
//  Created by Satendra Singh on 28/04/26.
//
import AppKit

final class SCUIUtility {
    static func checkNetworkAndShowNetworkAlert() -> Bool {

        if !SCUtility.networkConnectionIsAvailable() {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No network connection detected", comment: "No network connection detected message")
            alert.informativeText = NSLocalizedString("A block cannot be started without a working network connection.  You can override this setting in Preferences.", comment: "Message when network connection is unavailable")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
            alert.runModal()
            return false
        }
        return true
    }
}
