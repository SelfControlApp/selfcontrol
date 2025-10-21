//
//  Constants.swift
//  SelfControl
//
//  Created by Satendra Singh on 11/10/25.
//

enum Constants {
    /// File name for the JSON file with Safari rules.
    static let KEY_UUID = "uuid"
    static let KEY_PROCESS_ID = "pid"
    static let KEY_PROCESS_ARGS = "args"
    static let KEY_PROCESS_NAME = "name"
    static let KEY_PROCESS_PATH = "path"
    static let KEY_INDEX = "index"
    static let KEY_PATH = "paths"
    static let KEY_CS_SIGNER = "signatureSigner"
    static let KEY_CS_ID = "signatureIdentifier"
    static let KEY_CS_INFO = "signingInfo"
    static let KEY_CS_AUTHS = "signatureAuthorities"
}

enum AllowedProcess: String {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    static var allCases: [AllowedProcess] = [.chrome, .safari]
    static func isAllowed(_ bundleID: String) -> Bool {
        allCases.contains(where: { $0.rawValue == bundleID })
    }
    
    static func isAllowedProcess(_ process: Process) -> Bool {
        let ancestors: [String] = process.ancestors?.value(forKey: "name") as? [String] ?? []
        return allCases.contains(where: { $0.rawValue == process.bundleID }) || ancestors.contains(where: { $0.lowercased().contains("chrome") || $0.lowercased().contains("safari") })
    }
}
