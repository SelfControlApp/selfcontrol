//
//  LaunchAgentManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 13/05/26.
//


import Foundation

final class LaunchAgentManager {

    static let label = "com.application.SelfControl.corebits.bgservice"
    static let processName = "SelfControlBGService"

    static let plistName = "com.application.SelfControl.corebits.bgservice"
    
    static func install() throws {

        let fm = FileManager.default

        let sourcePlist = Bundle.main.url(
            forResource: plistName,
            withExtension: "plist"
        )!

        let launchAgentsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")

        let destinationPlist = launchAgentsDir
            .appendingPathComponent("\(plistName).plist")

        // Create LaunchAgents directory if needed
        try fm.createDirectory(
            at: launchAgentsDir,
            withIntermediateDirectories: true
        )

        // Replace old plist
        if fm.fileExists(atPath: destinationPlist.path) {
            try fm.removeItem(at: destinationPlist)
        }

        try fm.copyItem(
            at: sourcePlist,
            to: destinationPlist
        )

        // unload existing
        try runLaunchctl([
            "unload",
            destinationPlist.path
        ])

        // load new
        try runLaunchctl([
            "load",
            destinationPlist.path
        ])

        print("LaunchAgent installed")
    }

    static func uninstall() throws {

        let fm = FileManager.default

        let plist = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/LaunchAgents/\(plistName).plist"
            )

        try runLaunchctl([
            "unload",
            plist.path
        ])

        try fm.removeItem(at: plist)

        print("LaunchAgent removed")
    }

    @discardableResult
    static func runLaunchctl(_ args: [String]) throws -> String {

        let process = Process()

        process.executableURL = URL(
            fileURLWithPath: "/bin/launchctl"
        )

        process.arguments = args

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        return String(data: data, encoding: .utf8) ?? ""
    }
}

