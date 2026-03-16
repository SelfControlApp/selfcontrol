import Foundation

/// Entry point for the privileged helper daemon (com.max4c.stonectld).
@main
struct DaemonEntry {
    static func main() {
        let daemon = SCDaemon.shared
        daemon.start()
        RunLoop.current.run()
    }
}
