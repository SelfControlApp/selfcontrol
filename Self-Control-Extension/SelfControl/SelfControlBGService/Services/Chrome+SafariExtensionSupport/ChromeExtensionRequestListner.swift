//
//  PlistListner.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 16/08/25.
//

import Foundation
import Network
import os.log

enum ServicePath: String {
    case chrome = "/chrome"
    case safari = "/safari"
}

final class ChromeExtensionRequestListner: NSObject {
    private var isChromeStatusSetInExtension: Bool = false
    private let queue = DispatchQueue(label: "com.yourcompany.ChromeExtensionRequestListner", qos: .userInitiated)
    private(set) var listener: NWListener?
    var blockeddomainFetcher: (() -> [String])?
    var onExtensionStateChange: (() -> Void)?
    static let servicePort: UInt16 = 8532

    // MARK: - Public API

    func startListening() {
        // Convert Int port to NWEndpoint.Port
        guard let port = NWEndpoint.Port(rawValue: ChromeExtensionRequestListner.servicePort) else {
            BGFileLogger.error("\(#function) invalid service port: : \(ChromeExtensionRequestListner.servicePort)")
            return
        }

        do {
            let newListener = try NWListener(using: .tcp, on: port)
            self.listener = newListener

            // Configure service parameters if needed (e.g., fast open, local interface, etc.)
            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            newListener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerStateUpdate(state)
            }

            newListener.start(queue: queue)
        } catch {
            BGFileLogger.error("\(#function) failed to create NWListener: \(error.localizedDescription)")
        }
    }

    func stopListening() {
        listener?.cancel()
        listener = nil
    }

    deinit {
        stopListening()
    }

    // MARK: - Listener State Handling

    private func handleListenerStateUpdate(_ state: NWListener.State) {
        switch state {
        case .setup:
            os_log("[SC] 🔍] Listener setup")
            BGFileLogger.info("Listener state: setup")
        case .waiting(let error):
            os_log("[SC] 🔍] Listener waiting: %{public}@", error.localizedDescription)
            BGFileLogger.error("Listener waiting: \(error.localizedDescription)")

            // Optional: attempt a delayed restart if appropriate
            scheduleRestartIfNeeded()
        case .ready:
            os_log("[SC] 🔍] Listener ready on port %{public}d", ChromeExtensionRequestListner.servicePort)
            BGFileLogger.info("Listener state: ready on port \(ChromeExtensionRequestListner.servicePort)")
        case .failed(let error):
            os_log("[SC] 🔍] Listener failed: %{public}@", error.localizedDescription)
            BGFileLogger.error("Listener failed: \(error.localizedDescription)")

            // Cancel and clear; optionally try to restart after a delay
            listener?.cancel()
            listener = nil
            scheduleRestartIfNeeded()
        case .cancelled:
            os_log("[SC] 🔍] Listener cancelled")
            BGFileLogger.info("Listener state: cancelled")
        @unknown default:
            os_log("[SC] 🔍] Listener unknown state")
            BGFileLogger.error("Listener state: unknown")
        }
    }

    private func scheduleRestartIfNeeded() {
        // If you want to throttle restarts, add a backoff strategy here.
        // For now, try a simple delayed restart if listener is nil.
        guard listener == nil else { return }
        queue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            if self.listener == nil {
                self.startListening()
            }
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
//        BGFileLogger.info("New connection from: \(connection.endpoint.debugDescription)")
        os_log("[SC] 🔍] BG New connection from: %{public}@", connection.endpoint.debugDescription)

        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateUpdate(connection, state: state)
        }

        // Start the connection
        connection.start(queue: queue)

        // Receive a single HTTP request (simple, non-streaming)
        receiveHTTPRequest(on: connection)
    }

    private func handleConnectionStateUpdate(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .setup:
            BGFileLogger.info("Conn state: setup")
        case .waiting(let error):
            BGFileLogger.error("Conn state: waiting - \(error.localizedDescription)")
        case .ready:
            print("[SC] 🔍] BG Connection ready")
//            os_log("[SC] 🔍] BG Connection ready")
//            BGFileLogger.info("Conn state: ready")
        case .failed(let error):
            BGFileLogger.error("Conn state: failed - \(error.localizedDescription)")
            connection.cancel()
        case .cancelled:
            print("[SC] 🔍] BG Connection cancelled")
//            os_log("[SC] 🔍] BG Connection cancelled")
//            BGFileLogger.info("Conn state: cancelled")
        case .preparing:
            print("[SC] 🔍] BG Connection preparing")
//            os_log("[SC] 🔍] BG Connection preparing")

        @unknown default:
            os_log("[SC] 🔍] BG Conn state: unknown")

            BGFileLogger.error("Conn state: unknown")
        }
    }

    private func receiveHTTPRequest(on connection: NWConnection) {
        // Read up to some reasonable maximum for a small HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error = error {
                BGFileLogger.error("Receive error: \(error.localizedDescription)")
                self.sendHTTPError(.internalServerError, to: connection)
                connection.cancel()
                return
            }

            guard let data = data, !data.isEmpty else {
                BGFileLogger.error("Received empty data")
                self.sendHTTPError(.badRequest, to: connection)
                connection.cancel()
                return
            }

            guard let requestString = String(data: data, encoding: .utf8) else {
                BGFileLogger.error("Invalid UTF-8 in request")
                self.sendHTTPError(.badRequest, to: connection)
                connection.cancel()
                return
            }

            // Basic request parsing: we expect HTTP-like requests
            // Example: "GET /chrome HTTP/1.1\r\n..."
            let path = self.extractPath(from: requestString)

            // If the original helper exists, try to use it first
            if let service = requestString.httpPathFromConnection() {
                Task {
                    await AppStateManager.shared.handleApiRequest(path: service)
                }
                self.handleService(service, on: connection)
                return
            }

            // Fallback: handle based on parsed path
//            if let path {
//                Task {
//                    await AppStateManager.shared.handleApiRequest(path: path)
//                }
//                self.handlePath(path, on: connection)
//            }
            else {
                BGFileLogger.error("Unable to parse path from request \(path)")
                self.sendHTTPError(.notFound, to: connection)
            }

            // If the peer indicated end-of-stream, we can clean up
            if isComplete {
                connection.cancel()
            }
        }
    }

    // MARK: - Routing

    // If you have a specific enum for service paths, keep using it.
    // Here we just switch on known strings as a fallback.
    private func handleService(_ service: Any, on connection: NWConnection) {
        // The original code suggests `service` is an enum with cases .chrome and .safari.
        // We'll try to handle those names via String conversion for safety.
        let serviceString = String(describing: service).lowercased()
        switch serviceString {
        case "chrome":
            Task { [weak self] in
                await self?.sendChromeBlockedUrls(connection: connection)
            }
        case "safari":
            Task { [weak self] in
                await self?.sendChromeBlockedUrls(connection: connection)
            }
        default:
            // Unknown path
            sendHTTPError(.notFound, to: connection)
        }
    }

    private func handlePath(_ path: String, on connection: NWConnection) {
        switch path.lowercased() {
        case "/chrome", "chrome":
            Task { [weak self] in
                await self?.sendChromeBlockedUrls(connection: connection)
            }
        case "/safari", "safari":
            Task { [weak self] in
                await self?.sendChromeBlockedUrls(connection: connection)
            }
        default:
            sendHTTPError(.notFound, to: connection)
        }
    }

    // MARK: - Response Builders

    private func sendChromeBlockedUrls(connection: NWConnection) async {
        let isBlockEnabled = await AppStateManager.shared.isBlockingEnabled
        var blockedDomainList: [String] = self.blockeddomainFetcher?() ?? []

        if isBlockEnabled == false {
            blockedDomainList = []
        }

        let payload = ["blocked": blockedDomainList]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            sendHTTPResponse(status: .ok, contentType: "application/json", body: jsonData, to: connection)
        } catch {
            BGFileLogger.error("\(#function) JSON encode error: \(error.localizedDescription)")
            sendHTTPError(.internalServerError, to: connection)
        }
    }

    private func sendHTTPResponse(status: HTTPStatus, contentType: String, body: Data, to connection: NWConnection) {
        let headers = [
            "Content-Type": contentType,
            "Access-Control-Allow-Origin": "*",
            "Content-Length": "\(body.count)"
        ]

        let headerString = headers
            .map { "\($0): \($1)" }
            .joined(separator: "\r\n")

        let responseHead = "HTTP/1.1 \(status.code) \(status.reason)\r\n\(headerString)\r\n\r\n"
        var responseData = Data(responseHead.utf8)
        responseData.append(body)

        connection.send(content: responseData, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { error in
            if let error = error {
                BGFileLogger.error("Send response error: \(error.localizedDescription)")
            }
            // Close the connection after sending the response
            connection.cancel()
        })
    }

    private func sendHTTPError(_ status: HTTPStatus, to connection: NWConnection) {
        let bodyDict = ["error": status.reason]
        let bodyData = (try? JSONSerialization.data(withJSONObject: bodyDict, options: [])) ?? Data()
        sendHTTPResponse(status: status, contentType: "application/json", body: bodyData, to: connection)
    }

    // MARK: - Helpers

    private func extractPath(from request: String) -> String? {
        // Very simple parser: first line "METHOD /path HTTP/1.1"
        guard let firstLine = request.components(separatedBy: "\r\n").first else {
            return nil
        }
        let components = firstLine.split(separator: " ")
        guard components.count >= 2 else {
            return nil
        }
        return String(components[1])
    }
}

// MARK: - HTTPStatus

private enum HTTPStatus {
    case ok
    case badRequest
    case notFound
    case internalServerError

    var code: Int {
        switch self {
        case .ok: return 200
        case .badRequest: return 400
        case .notFound: return 404
        case .internalServerError: return 500
        }
    }

    var reason: String {
        switch self {
        case .ok: return "OK"
        case .badRequest: return "Bad Request"
        case .notFound: return "Not Found"
        case .internalServerError: return "Internal Server Error"
        }
    }
}

extension String {
    func httpPathFromConnection() -> ServicePath? {
        if let firstLine = components(separatedBy: "\r\n").first {
            print("Request Line:", firstLine)

            let parts = firstLine.split(separator: " ")
            if parts.count >= 2 {
                let path = parts[1]
                print("HTTP Path:", path)
                return ServicePath(rawValue: String(path))
            }
        }
        return nil
    }
}
