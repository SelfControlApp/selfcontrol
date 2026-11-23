import Foundation

/// One binary, two roles: the SwiftUI app, or (with --daemon, run as root by launchd) the helper.
@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--daemon") {
            HelperDaemon.run()
        } else {
            SelfControlNextApp.main()
        }
    }
}
