//
//  FileLogger.swift
//  SelfControl
//
//  Created by Satendra Singh on 12/06/26.
//

import Foundation
import OSLog

//struct FileLogger {
//    static let logger = Logger(subsystem: "com.application.SelfControl.corebits.bgservice", category: "service");
//}

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARNING"
    case error = "ERROR"
    case fault = "FAULT"
}

private actor FileLogger {
    public static let shared = FileLogger()

    private let logDirectoryURL: URL
    private let logFileURL: URL
    private let fileManager = FileManager.default
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let maxFileSizeBytes: Int64 = 5 * 1024 * 1024 // 5 MB
    private let maxRotatedFiles = 5

    public init(directoryName: String = "Logs", fileName: String = "app.log") {
        // Default to Application Support/<bundle-id>/Logs/app.log
        let baseDir: URL
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDir = appSupport
        } else {
            baseDir = URL(fileURLWithPath: NSTemporaryDirectory())
        }

        let bundleID = appName + (Bundle.main.bundleIdentifier ?? Bundle.main.bundleURL.lastPathComponent)
        let appDir = baseDir.appendingPathComponent(bundleID, isDirectory: true)

        self.logDirectoryURL = appDir.appendingPathComponent(directoryName, isDirectory: true)
        self.logFileURL = logDirectoryURL.appendingPathComponent(fileName)
        os_log("[SC] 🔍] BG LOG Dir: %{public}@", log: OSLog.default, type: .debug, logDirectoryURL.path)

        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
    }

    // Call once at app start or before first log
    public func start() async {
        do {
            try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            if !fileManager.fileExists(atPath: logFileURL.path) {
                fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            }
            fileHandle = try FileHandle(forWritingTo: logFileURL)
            try fileHandle?.seekToEnd()
        } catch {
            // As a fallback, ignore failures silently to avoid crashing logging
            fileHandle = nil
        }
    }

    public func stop() async {
        try? fileHandle?.close()
        fileHandle = nil
    }

    public func debug(_ message: @autoclosure () -> String) async {
        await write(level: .debug, message())
    }

    public func info(_ message: @autoclosure () -> String) async {
        await write(level: .info, message())
    }

    public func notice(_ message: @autoclosure () -> String) async {
        await write(level: .notice, message())
    }

    public func warning(_ message: @autoclosure () -> String) async {
        await write(level: .warning, message())
    }

    public func error(_ message: @autoclosure () -> String) async {
        await write(level: .error, message())
    }

    public func fault(_ message: @autoclosure () -> String) async {
        await write(level: .fault, message())
    }

    public func log(_ level: LogLevel, _ message: @autoclosure () -> String) async {
        await write(level: level, message())
    }

    private func write(level: LogLevel, _ message: @autoclosure () -> String) async {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] \(message())\n"

        // Ensure file is ready
        if fileHandle == nil {
            await start()
        }

        // Attempt rotation when file too large
        await rotateIfNeeded()

        guard let data = line.data(using: .utf8) else { return }

        do {
            try fileHandle?.seekToEnd()
            try fileHandle?.write(contentsOf: data)
        } catch {
            // If writing fails, try reopening once
            do {
                try fileHandle?.close()
                fileHandle = try FileHandle(forWritingTo: logFileURL)
                try fileHandle?.seekToEnd()
                try fileHandle?.write(contentsOf: data)
            } catch {
                os_log("[SC] 🔍] File handler error: %{public}@", error.localizedDescription)
                // Give up silently to avoid crashing the app
            }
        }
    }

    private func rotateIfNeeded() async {
        guard let attrs = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? NSNumber else { return }

        if size.int64Value < maxFileSizeBytes { return }

        // Close current file first
        try? fileHandle?.close()
        fileHandle = nil

        // Rotate existing files: app.log.(n) -> app.log.(n+1)
        for index in stride(from: maxRotatedFiles - 1, through: 1, by: -1) {
            let src = logFileURL.appendingPathExtension("\(index)")
            let dst = logFileURL.appendingPathExtension("\(index + 1)")
            if fileManager.fileExists(atPath: src.path) {
                try? fileManager.removeItem(at: dst)
                try? fileManager.moveItem(at: src, to: dst)
            }
        }

        // Move current app.log -> app.log.1
        let firstRotation = logFileURL.appendingPathExtension("1")
        try? fileManager.removeItem(at: firstRotation)
        try? fileManager.moveItem(at: logFileURL, to: firstRotation)

        // Create a new empty log file
        fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        do {
            fileHandle = try FileHandle(forWritingTo: logFileURL)
            try fileHandle?.seekToEnd()
        } catch {
            fileHandle = nil
        }
    }

    // Convenience to get the current log file URL (for sharing or debug)
    public func currentLogFileURL() -> URL {
        logFileURL
    }

    public func allLogFiles() -> [URL] {
        var urls: [URL] = [logFileURL]
        for i in 1...maxRotatedFiles {
            let rotated = logFileURL.appendingPathExtension("\(i)")
            if fileManager.fileExists(atPath: rotated.path) {
                urls.append(rotated)
            }
        }
        return urls
    }
}

struct BGFileLogger {
    static func debug(_ message: String) { Task { await FileLogger.shared.debug(message) }}
    static func info(_ message: String) { Task { await FileLogger.shared.info(message) } }
    static func notice(_ message: String) { Task { await FileLogger.shared.notice(message) } }
    static func warning(_ message: String) { Task { await FileLogger.shared.warning(message) } }
    static func error(_ message: String) { Task { await FileLogger.shared.error(message)} }
    static func fault(_ message: String) { Task { await FileLogger.shared.fault(message) } }
}
