//
//  SafariExtensionViewController.swift
//  test Safari Ext Extension
//
//  Created by Satendra Singh on 30/10/25.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:320, height:240)
        return shared
    }()

}
