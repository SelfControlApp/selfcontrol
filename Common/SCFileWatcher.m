//
//  SCFileWatcher.m
//  SelfControl
//
//  Created by Charlie Stigler on 3/20/21.
//

#import "SCFileWatcher.h"
#include <CoreServices/CoreServices.h>

@implementation SCFileWatcher

static void SCFileWatcherGlobalCallback(
    ConstFSEventStreamRef streamRef,
    void *callbackCtxInfo,
    size_t numEvents,
    void *eventPaths, // CFArrayRef
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[])
{
    NSArray* paths = (__bridge NSArray*)eventPaths;
    SCFileWatcher* watcher = (__bridge SCFileWatcher*)callbackCtxInfo;
    [watcher directoryWatcherTriggered: paths flags: eventFlags];
}

- (void)directoryWatcherTriggered:(NSArray<NSString*>*)eventPaths flags:(const FSEventStreamEventFlags[])eventFlags {
    BOOL triggerFileWatcher = NO;

    for (unsigned int i = 0; i < eventPaths.count; i++) {
        NSString* eventPath = [eventPaths[i] stringByStandardizingPath];
        
        if ([eventPath isEqualToString: self.filePath]) {
            triggerFileWatcher = YES;
        }
    }
    
    if (triggerFileWatcher) {
        self.callbackBlock(nil);
    }
}

+ (instancetype)watcherWithFile:(NSString*)watchPath block:(void(^)(NSError* error))callbackBlock {
    return [[SCFileWatcher new] initWithFile: watchPath block: callbackBlock];
}

- (instancetype)initWithFile:(NSString*)watchPath block:(void(^)(NSError* error))callbackBlock {
    self = [super init];

    NSFileManager* fileMan = [NSFileManager defaultManager];
    _filePath = [watchPath stringByStandardizingPath];
    BOOL isDirectory;
    [fileMan fileExistsAtPath: self.filePath isDirectory: &isDirectory];
    
    NSString* directoryPath;
    if (isDirectory) {
        directoryPath = self.filePath;
    } else {
        directoryPath = [self.filePath stringByDeletingLastPathComponent];
    }

    FSEventStreamContext callbackCtx;
    callbackCtx.version = 0;
    callbackCtx.info = (__bridge void *)self;
    callbackCtx.retain = NULL;
    callbackCtx.release = NULL;
    callbackCtx.copyDescription = NULL;

    FSEventStreamRef eventStream = FSEventStreamCreate(
        kCFAllocatorDefault,
        &SCFileWatcherGlobalCallback,
        &callbackCtx, // context
        (__bridge CFArrayRef)@[directoryPath],
        kFSEventStreamEventIdSinceNow,
        1.5, // seconds to throttle callbacks
        kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagMarkSelf | kFSEventStreamCreateFlagIgnoreSelf | kFSEventStreamCreateFlagFileEvents
    );
    
    FSEventStreamScheduleWithRunLoop(eventStream,
                                     [[NSRunLoop currentRunLoop] getCFRunLoop],
                                     kCFRunLoopDefaultMode);
    if (!FSEventStreamStart(eventStream)) {
        NSLog(@"WARNING: failed to start watching file %@", watchPath);
        FSEventStreamUnscheduleFromRunLoop(eventStream, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopDefaultMode);
        FSEventStreamInvalidate(eventStream);
        FSEventStreamRelease(eventStream);
        return nil;
    }
    
    _eventStream = eventStream;
    _callbackBlock = callbackBlock;
    
    return self;
}

- (void)stopWatching {
    FSEventStreamStop(self.eventStream);
    FSEventStreamUnscheduleFromRunLoop(self.eventStream, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopDefaultMode);
    FSEventStreamInvalidate(self.eventStream);
    FSEventStreamRelease(self.eventStream);

    _eventStream = NULL;
}

@end
