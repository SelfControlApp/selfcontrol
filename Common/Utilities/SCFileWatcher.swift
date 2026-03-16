import Foundation
import CoreServices

/// Watches a file or directory for changes using FSEvents.
class SCFileWatcher {
    private var stream: FSEventStreamRef?
    private let path: String
    private let callback: () -> Void

    init(path: String, callback: @escaping () -> Void) {
        self.path = path
        self.callback = callback
    }

    func start() {
        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        )

        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<SCFileWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.callback()
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency in seconds
            flags
        ) else { return }

        self.stream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
