//
//  Strings.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import Foundation

struct Strings {
    // MARK: - Common
    struct Common {
        static let back = "Back"
        static let cancel = "Cancel"
        static let done = "Done"
        static let delete = "Delete"
        static let add = "Add"
        static let edit = "Edit"
        static let importText = "Import"
        static let export = "Export"
        static let selectAll = "Select All"
        static let deselectAll = "Deselect All"
    }
    
    // MARK: - Main Screen
    struct MainScreen {
        static let startBlock = "Start Block"
        static let stopBlocking = "Stop Blocking"
        static let intensity = "INTENSITY"
        static let willBlock = "Will Block"
        static let willAllow = "Will Allow (Blocks ALL Else)"
        static let noSitesBlocked = "No sites blocked"
        static let blocklistEmpty = "Blocklist is empty"
        static let blocking = "Blocking"
        static let noSitesAllowed = "No sites allowed"
        static let allWebsitesBlocked = "All websites are blocked"
        static let allowing = "Allowing"
        static let allOtherSitesBlocked = "All other sites are blocked"
        static let addToBlocklist = "Add to Blocklist"
        static let addToAllowlist = "Add to Allowlist"
        
        // Time presets
        static let oneMinute = "1 min"
        static let sixHours = "6h"
        static let twelveHours = "12h"
        static let eighteenHours = "18h"
        static let twentyFourHours = "24h"
        
        // Time units
        static let hours = "h"
        static let minutes = "m"
        static let days = "d"
        
        // Confirmation alert
        static let startBlockingTitle = "Start Blocking?"
        static func startBlockingMessage(blockingMode: BlockingMode, countText: String, timeDisplay: String) -> String {
            if blockingMode == .allowlist {
                return "⚠️ ALLOWLIST MODE: You will block ALL websites EXCEPT \(countText) for \(timeDisplay).\n\nOnly sites on your list will be accessible. You won't be able to stop until the timer expires."
            } else {
                return "You will block \(countText) for \(timeDisplay). You won't be able to stop until the timer expires."
            }
        }
    }
    
    // MARK: - Blocklist Editor
    struct BlocklistEditor {
        static let title = "Blocklist"
        static let allowlist = "Allowlist"
        static let allowlistModeActive = "ALLOWLIST MODE ACTIVE"
        static let allowlistModeDescription = "Only sites on this list will be accessible. Everything else will be blocked."
        static let quickAdd = "Quick Add"
        static let suggested = "Suggested"
        static let tips = "Tips"
        static let bulkEdit = "Bulk Edit"
        static let sites = "SITE"
        static let sitesPlural = "SITES"
        static let noBlockedSites = "No blocked sites yet"
        static let noResultsFound = "No results found"
        static let locked = "(locked)"
        static let path = "path"
        static let paths = "paths"
        static let selected = "selected"
        
        // Placeholders
        static let searchPlaceholder = "Search..."
        static let addWebsitePlaceholder = "Add website..."
        static let addWebsiteExamplePlaceholder = "Add website (e.g., facebook.com)"
        static let searchBlockedSitesPlaceholder = "Search blocked sites"
        
        static func siteCount(_ count: Int) -> String {
            "\(count) \(count == 1 ? sites : sitesPlural)"
        }
        static func pathCount(_ count: Int) -> String {
            "\(count) \(count == 1 ? path : paths)"
        }
        static func selectedCount(_ count: Int) -> String {
            "\(count) \(selected)"
        }
        
        // Delete confirmation
        static func deleteSiteTitle(_ count: Int) -> String {
            "Delete \(count) Site\(count == 1 ? "" : "s")?"
        }
        static func deleteSiteMessage(_ count: Int) -> String {
            "Are you sure you want to delete \(count == 1 ? "this site" : "these sites")? This action cannot be undone."
        }
        
        // Add site confirmation
        static let addToExistingBlockTitle = "Add to Existing Block?"
        static func addToExistingBlockMessage(_ site: String, blockingMode: BlockingMode) -> String {
            "Are you sure you want to add \"\(site)\" to your \(blockingMode == .blocklist ? "blocklist" : "allowlist") while a block is active?"
        }
        static let addSite = "Add Site"
    }
    
    // MARK: - Domain Detail
    struct DomainDetail {
        static let siteSettings = "Site Settings"
        static let blockingMode = "BLOCKING MODE"
        static let blockEntireDomain = "Block Entire Domain"
        static let specificPathsOnly = "Specific Paths Only"
        static let blockEntireDomainDescription = "Blocks all pages on this domain"
        static let specificPathsDescription = "Only blocks specific paths/subdomains you add below"
        static let pathsAndSubdomains = "PATHS & SUBDOMAINS"
        static let addPathOrSubdomain = "Add Path or Subdomain"
        static let paths = "Paths"
        static func pathsCount(_ count: Int) -> String {
            "Paths (\(count))"
        }
        static let noPathsAdded = "No paths added yet"
        static let deleteSite = "Delete Site"
        static let managePathsDescription = "Manage specific paths and subdomains for this website"
        
        // Placeholders
        static let addPathPlaceholder = "e.g., /explore, /reels"
        static let addPathExamplePlaceholder = "e.g., /explore, /reels, or m.domain.com"
    }
    
    // MARK: - Advanced Settings
    struct AdvancedSettings {
        static let title = "More Settings"
        static let blocking = "BLOCKING"
        static let general = "GENERAL"
        static let networkAndCache = "NETWORK & CACHE"
        static let displayAndTimer = "DISPLAY & TIMER"
        static let mode = "MODE"
        static let allowlistMode = "Allowlist Mode"
        static let allowlistModeDescription = "Blocks ALL sites except those on the list"
        
        // Allowlist confirmation
        static let enableAllowlistTitle = "⚠️ Enable Allowlist Mode?"
        static let enableAllowlistMessage = "WARNING: Allowlist mode blocks EVERYTHING except sites on your list.\n\nOnly the sites you explicitly add will be accessible. All other websites, apps, and services will be blocked. Use this mode with caution."
        static let enableAllowlist = "Enable Allowlist"
        
        // Setting titles
        static let blockCommonSubdomains = "Block common subdomains"
        static let highlightInvalidHosts = "Highlight invalid hosts"
        static let allowlistLinkedSites = "Allowlist includes linked sites (slow)"
        static let autoCheckUpdates = "Automatically check for updates"
        static let autoSendErrorReports = "Automatically send anonymized error reports"
        static let playSoundOnCompletion = "Play sound on completion"
        static let timerFloatsOnTop = "Timer window should float on top"
        static let showCountdownInDock = "Show countdown in Dock"
        static let hideSecondsInCountdown = "Hide seconds in countdown"
        static let verifyInternetConnection = "Verify internet connection"
        static let clearBrowserCache = "Clear browser cache"
        static let allowLocalNetworks = "Allow local networks"
    }
    
    // MARK: - Block Schedule
    struct BlockSchedule {
        static let title = "Block Schedule"
        static let noTimeSlots = "No time slots"
        static let addTimeSlot = "Add Time Slot"
        static let deleteSchedule = "Delete Schedule"
        static let to = "to"
    }
    
    // MARK: - About
    struct About {
        static let title = "About SelfControl"
        static let appName = "SelfControl"
        static let version = "Version 4.0.2 (410)"
        static let freeAndOpenSource = "Free and open-source under the GPL."
        
        // Main website link
        static let mainWebsite = AboutItem(text: "http://selfcontrolapp.com", url: "http://selfcontrolapp.com")
        
        // Credits sections as arrays (each array represents one line/row)
        static let developers: [AboutItem] = [
            AboutItem(text: "Developed by"),
            AboutItem(text: "Charlie Stigler", url: "https://github.com/cstigler"),
            AboutItem(text: ","),
            AboutItem(text: "Steve Lambert", url: "http://visitsteve.com"),
            AboutItem(text: ", and you?")
        ]
        
        static let iconAndContributorsLine1: [AboutItem] = [
            AboutItem(text: "Icon by"),
            AboutItem(text: "Joseph Fusco", url: "http://josephfus.co/"),
            AboutItem(text: ", contributions by all of")
        ]
        
        static let iconAndContributorsLine2: [AboutItem] = [
            AboutItem(text: "these lovely folks", url: "https://github.com/SelfControlApp/selfcontrol/graphs/contributors"),
            AboutItem(text: ", and translations by"),
            AboutItem(text: "these troopers", url: "https://www.transifex.com/selfcontrol/selfcontrol/"),
            AboutItem(text: ".")
        ]
        
        static let errorReporting: [AboutItem] = [
            AboutItem(text: "Error reporting generously provided by"),
            AboutItem(text: "Sentry", url: "https://sentry.io"),
            AboutItem(text: ".")
        ]
        
        static let license: [AboutItem] = [
            AboutItem(text: "Free Software created at"),
            AboutItem(text: "Eyebeam", url: "http://eyebeam.org"),
            AboutItem(text: "under the"),
            AboutItem(text: "GNU GPL", url: "http://www.gnu.org/copyleft/gpl.html"),
            AboutItem(text: ".")
        ]
        
        static let sourceCode: [AboutItem] = [
            AboutItem(text: "Source code", url: "https://github.com/SelfControlApp/selfcontrol/"),
            AboutItem(text: "is available on GitHub.")
        ]
    }
    
    // MARK: - Tips
    struct Tips {
        static let title = "Getting Started with SelfControl"
        static let gotIt = "Got it"
        
        // Tips as an array
        static let items: [Tip] = [
            Tip(
                title: "1. Add Sites to Block",
                description: "Click 'Edit' to add website domains or paths you want to block."
            ),
            Tip(
                title: "2. Adjust Blocking Time and Intensity",
                description: "Set how long you want to block sites and the intensity of the blocking."
            ),
            Tip(
                title: "3. Start Blocking",
                description: "Click 'Start Block' to begin."
            )
        ]
    }
    
    // MARK: - Stop Confirmation
    struct StopConfirmation {
        static let title = "Stop Blocking?"
        static let seconds = "seconds"
        static let yesStopBlocking = "Yes, Stop Blocking"
        static let resumeBlocking = "Resume Blocking"
        static func countdownMessage(_ countdownTime: TimeInterval) -> String {
            if countdownTime > 0 {
                let minutes = Int(countdownTime) / 60
                let seconds = Int(countdownTime) % 60
                if minutes > 0 {
                    return "Wait for \(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s") before you can stop blocking"
                } else {
                    return "Wait for \(seconds) second\(seconds == 1 ? "" : "s") before you can stop blocking"
                }
            } else {
                return "Confirm below to stop blocking"
            }
        }
    }
    
    // MARK: - Help Text
    struct Help {
        static let closeSearch = "Close search"
        static let addSite = "Add site"
        static let search = "Search"
        static let showTips = "Show getting started tips"
        static let cannotDisableDuringBlock = "Cannot disable sites while a block is active"
        static let stopBlockingImmediately = "Stop blocking immediately"
        static let stopBlockingWithConfirmation = "Stop blocking with confirmation"
        static let clickToEditTime = "Click to edit time"
        static let startBlocking = "Start blocking"
        static let cannotChangeModeDuringBlock = "Cannot change blocking mode while a block is active"
    }
    
    // MARK: - Blocked URLs Helpers
    struct BlockedURLs {
        static let noSites = "No sites"
        static let allSitesDisabled = "All sites disabled"
        static let domain = "domain"
        static let domains = "domains"
        static func domainCount(_ count: Int, total: Int) -> String {
            "\(count)/\(total) domain\(count == 1 ? "" : "s")"
        }
        static func domainsText(_ count: Int) -> String {
            "\(count) domain\(count == 1 ? "" : "s")"
        }
    }
    
    // MARK: - App Menu
    struct AppMenu {
        static let aboutSelfControl = "About SelfControl"
        static let editSiteList = "Edit Block List"
        static let editBlockSchedule = "Edit Block Schedule"
        static let moreSettings = "More Settings"
        static let donate = "Donate"
        static let gettingStartedTips = "Getting Started Tips"
        static let selfControlHelp = "SelfControl Help"
        static let faq = "FAQ"
        
        // URLs
        struct URLs {
            static let donate = "https://selfcontrolapp.com/donate"
            static let help = "https://github.com/SelfControlApp/selfcontrol/wiki/SelfControl-Support-Hub"
            static let faq = "https://github.com/SelfControlApp/selfcontrol/wiki/FAQ"
        }
    }
}

