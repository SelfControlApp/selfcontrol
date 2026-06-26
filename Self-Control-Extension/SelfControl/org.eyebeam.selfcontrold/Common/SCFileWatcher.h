//
//  SCFileWatcher.h
//  SelfControl
//
//  Created by Charlie Stigler on 3/20/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SCFileWatcherCallback)(NSError* _Nullable error);

@interface SCFileWatcher : NSObject

@property (readonly) FSEventStreamRef eventStream;
@property (strong, readonly) SCFileWatcherCallback callbackBlock;
@property (strong, readonly) NSString* filePath;

+ (instancetype)watcherWithFile:(NSString*)watchPath block:(void(^)(NSError* error))callbackBlock;
- (instancetype)initWithFile:(NSString*)watchPath block:(void(^)(NSError* error))callbackBlock;

- (void)stopWatching;

@end

NS_ASSUME_NONNULL_END
