import Foundation

/// All Stone error codes, matching the original SelfControl error domain.
enum SCError: Int, LocalizedError {
    case blockAlreadyRunning = 301
    case emptyBlocklist = 302
    case blockEndDateInPast = 303
    case authorizationFailed = 304
    case daemonInstallFailed = 305
    case daemonConnectionFailed = 306
    case blockNotRunning = 307
    case blockFileReadFailed = 308
    case blockFileWriteFailed = 309
    case settingsSyncFailed = 310
    case pfctlFailed = 311
    case hostsWriteFailed = 312
    case blockIntegrityFailed = 313
    case invalidBlocklistEntry = 314
    case updateEndDateInvalid = 315
    case updateEndDateTooFar = 316

    var errorDescription: String? {
        switch self {
        case .blockAlreadyRunning: return "A block is already running."
        case .emptyBlocklist: return "The blocklist is empty."
        case .blockEndDateInPast: return "The block end date is in the past."
        case .authorizationFailed: return "Authorization failed."
        case .daemonInstallFailed: return "Failed to install the helper daemon."
        case .daemonConnectionFailed: return "Failed to connect to the helper daemon."
        case .blockNotRunning: return "No block is currently running."
        case .blockFileReadFailed: return "Failed to read the blocklist file."
        case .blockFileWriteFailed: return "Failed to write the blocklist file."
        case .settingsSyncFailed: return "Failed to sync settings."
        case .pfctlFailed: return "Failed to update packet filter rules."
        case .hostsWriteFailed: return "Failed to update /etc/hosts."
        case .blockIntegrityFailed: return "Block integrity check failed."
        case .invalidBlocklistEntry: return "Invalid blocklist entry."
        case .updateEndDateInvalid: return "New end date must be later than current end date."
        case .updateEndDateTooFar: return "Cannot extend block by more than 24 hours."
        }
    }

    static let domain = "com.max4c.stone.error"
}
