#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Baked-in pin list for the trusted-time HTTPS gate. Each entry is
/// @{ @"host": @"<hostname>", @"spki": @"<base64 SHA-256 of leaf SPKI>" }.
/// The quorum check requires 2 of 3 to succeed, so a single rotation
/// failure does not break the gate.
@interface SCPinnedHosts : NSObject

+ (NSArray<NSDictionary<NSString*, NSString*>*>*)hosts;

@end

NS_ASSUME_NONNULL_END
