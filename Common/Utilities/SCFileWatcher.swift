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

        // [Fix #6] Use passRetained to prevent use-after-free if watcher is
        // deallocated before the stream is invalidated.
        var context = FSEventStreamContext()
        context.info = Unmanaged.passRetained(self).toOpaque()
        context.release = { info in
            guard let info = info else { return }
            Unmanaged<SCFileWatcher>.fromOpaque(info).release()
        }

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
