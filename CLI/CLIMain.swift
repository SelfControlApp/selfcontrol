import Foundation

/// Entry point for the stone-cli command-line tool.
@main
struct CLIEntry {
    static func main() {
        let args = CommandLine.arguments

        guard args.count > 1 else {
            Self.printUsage()
            exit(EXIT_SUCCESS)
        }

        let command = args[1]

        switch command {
        case "start", "--start", "--install":
            // TODO: Parse args, call SCXPCClient to start block
            print("stone-cli: start not yet implemented")
            exit(EXIT_FAILURE)

        case "is-running", "--isrunning", "-r":
            let isRunning = SCBlockUtilities.anyBlockIsRunning()
            print(isRunning ? "YES" : "NO")

        case "print-settings", "--printsettings", "-p":
            let settings = SCSettings.shared.dictionaryRepresentation()
            print(settings)

        case "version", "--version", "-v":
            print(StoneConstants.versionString)

        default:
            Self.printUsage()
        }
    }

    static func printUsage() {
        print("""
        Stone CLI Tool v\(StoneConstants.versionString)
        Usage: stone-cli [--uid <controlling user ID>] <command> [<args>]

        Valid commands:

            start --> starts a Stone block
                --blocklist <path to saved blocklist file>
                --enddate <specified end date for block in ISO8601 format>
                --duration <block duration in minutes (alternative to --enddate)>
                --settings <other block settings in JSON format>

            is-running --> prints YES if a Stone block is currently running, or NO otherwise

            print-settings --> prints the Stone settings being used for the active block

            version --> prints the version of the Stone CLI tool

        Example: stone-cli start --blocklist /path/to/blocklist.stone --duration 60
        """)
    }
}
