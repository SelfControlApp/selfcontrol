#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Trusted-internet time verification for the block unlock gate.
/// All callers must be prepared for any method to return nil/NO on failure.
@interface SCTrustedTime : NSObject

/// Parses an HTTP IMF-fixdate (RFC 7231 §7.1.1.1). Returns nil on any error.
+ (nullable NSDate*)parseHTTPDateHeader:(nullable NSString*)header;

typedef void (^SCTrustedTimeCompletion)(NSDate* _Nullable verifiedTime, NSError* _Nullable error);

/// Fetches https://<host>/ HEAD and returns the time from the Date: header IFF
/// the server's leaf SubjectPublicKeyInfo SHA-256 (base64) matches expectedSPKI.
+ (void)fetchTimeFromHost:(NSString*)host
             expectedSPKI:(NSString*)spki
                  timeout:(NSTimeInterval)timeoutSeconds
               completion:(SCTrustedTimeCompletion)completion;

typedef void (^SCTrustedTimeQuorumCompletion)(BOOL verified, NSDate* _Nullable medianTime, NSError* _Nullable error);

/// Returns verified=YES iff at least 2 pinned hosts respond, all returned times
/// are within 5 minutes of each other, and the median response is >= threshold.
+ (void)verifyTimeIsAfter:(NSDate*)threshold
               completion:(SCTrustedTimeQuorumCompletion)completion;

@end

NS_ASSUME_NONNULL_END
