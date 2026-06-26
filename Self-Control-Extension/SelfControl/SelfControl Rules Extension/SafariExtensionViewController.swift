//
//  SafariExtensionViewController.swift
//  SelfControl Rules Extension
//
//  Created by Satendra Singh on 16/11/25.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:320, height:240)
        return shared
    }()

}
