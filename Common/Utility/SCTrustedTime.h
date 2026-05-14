#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Trusted-internet time verification for the block unlock gate.
/// All callers must be prepared for any method to return nil/NO on failure.
@interface SCTrustedTime : NSObject

/// Parses an HTTP IMF-fixdate (RFC 7231 §7.1.1.1). Returns nil on any error.
+ (nullable NSDate*)parseHTTPDateHeader:(nullable NSString*)header;

@end

NS_ASSUME_NONNULL_END
