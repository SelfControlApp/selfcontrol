//
//  FilterController.swift
//  SelfControl
//
//  Created by Satendra Singh on 26/05/26.
//


import NetworkExtension
import os.log

final class FilterController {
    static func restartFilter(completion: @escaping (Error?) -> Void) {
        os_log("[SC] 🔍] BG restartFilter:")
        NEFilterManager.shared().loadFromPreferences { error in
            if let error = error {
                completion(error)
                return
            }

            let manager = NEFilterManager.shared()
            // If it’s not enabled, just enable it once.
            guard manager.isEnabled else {
                manager.isEnabled = true
                manager.saveToPreferences { saveError in
                    completion(saveError)
                }
                return
            }

            // Disable first
            manager.isEnabled = false
            manager.saveToPreferences { disableError in
                if let disableError = disableError {
                    completion(disableError)
                    return
                }

                // Re-enable
                manager.isEnabled = true
                manager.saveToPreferences { enableError in
                    completion(enableError)
                }
            }
        }
    }
}
