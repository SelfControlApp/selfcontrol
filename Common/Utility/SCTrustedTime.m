#import "SCTrustedTime.h"
#import "SCPinnedHosts.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

@interface SCTrustedTimePinningDelegate : NSObject <NSURLSessionDelegate>
@property (copy) NSString* expectedSPKI;
@end

@implementation SCTrustedTimePinningDelegate

- (void)URLSession:(NSURLSession*)session
didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
 completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition, NSURLCredential* _Nullable))ch
{
    if (![challenge.protectionSpace.authenticationMethod isEqualToString: NSURLAuthenticationMethodServerTrust]) {
        ch(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    if (trust == NULL) { ch(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil); return; }

    CFIndex count = SecTrustGetCertificateCount(trust);
    BOOL matched = NO;
    for (CFIndex i = 0; i < count && !matched; i++) {
        SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, i);
        SecKeyRef pubkey = SecCertificateCopyKey(cert);
        if (pubkey == NULL) continue;
        CFErrorRef err = NULL;
        CFDataRef der = SecKeyCopyExternalRepresentation(pubkey, &err);
        CFRelease(pubkey);
        if (der == NULL) continue;
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(CFDataGetBytePtr(der), (CC_LONG)CFDataGetLength(der), digest);
        NSData* digestData = [NSData dataWithBytes: digest length: CC_SHA256_DIGEST_LENGTH];
        NSString* b64 = [digestData base64EncodedStringWithOptions: 0];
        CFRelease(der);
        if ([b64 isEqualToString: self.expectedSPKI]) matched = YES;
    }

    if (matched) {
        ch(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust: trust]);
    } else {
        ch(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}

@end

@implementation SCTrustedTime

+ (NSDateFormatter*)imfFormatter {
    static NSDateFormatter* f = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier: @"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneWithAbbreviation: @"GMT"];
        f.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
    });
    return f;
}

+ (NSDate*)parseHTTPDateHeader:(NSString*)header {
    if (header.length == 0) return nil;
    return [[self imfFormatter] dateFromString: header];
}

+ (void)fetchTimeFromHost:(NSString*)host
             expectedSPKI:(NSString*)spki
                  timeout:(NSTimeInterval)timeoutSeconds
               completion:(SCTrustedTimeCompletion)completion
{
    SCTrustedTimePinningDelegate* d = [SCTrustedTimePinningDelegate new];
    d.expectedSPKI = spki;
    NSURLSessionConfiguration* cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = timeoutSeconds;
    NSURLSession* session = [NSURLSession sessionWithConfiguration: cfg delegate: d delegateQueue: nil];

    NSURL* url = [NSURL URLWithString: [NSString stringWithFormat: @"https://%@/", host]];
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL: url];
    req.HTTPMethod = @"HEAD";

    [[session dataTaskWithRequest: req completionHandler:^(NSData* data, NSURLResponse* resp, NSError* error) {
        [session finishTasksAndInvalidate];
        if (error) { completion(nil, error); return; }
        NSHTTPURLResponse* http = (NSHTTPURLResponse*)resp;
        NSString* dateStr = http.allHeaderFields[@"Date"];
        NSDate* parsed = [SCTrustedTime parseHTTPDateHeader: dateStr];
        if (parsed == nil) {
            completion(nil, [NSError errorWithDomain: @"SCTrustedTime" code: 1
                                            userInfo: @{NSLocalizedDescriptionKey: @"No/invalid Date header"}]);
            return;
        }
        completion(parsed, nil);
    }] resume];
}

+ (void)verifyTimeIsAfter:(NSDate*)threshold completion:(SCTrustedTimeQuorumCompletion)completion {
    NSArray* hosts = [SCPinnedHosts hosts];
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSDate*>* results = [NSMutableArray array];
    NSLock* lock = [NSLock new];

    for (NSDictionary* hp in hosts) {
        dispatch_group_enter(group);
        [self fetchTimeFromHost: hp[@"host"]
                   expectedSPKI: hp[@"spki"]
                        timeout: 8.0
                     completion:^(NSDate* d, NSError* e) {
            if (d != nil) {
                [lock lock]; [results addObject: d]; [lock unlock];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        if (results.count < 2) {
            completion(NO, nil, [NSError errorWithDomain: @"SCTrustedTime" code: 2
                                                userInfo: @{NSLocalizedDescriptionKey: @"Quorum not reached"}]);
            return;
        }
        NSArray* sorted = [results sortedArrayUsingSelector: @selector(compare:)];
        NSDate* min = sorted.firstObject;
        NSDate* max = sorted.lastObject;
        if ([max timeIntervalSinceDate: min] > 300.0) {
            completion(NO, nil, [NSError errorWithDomain: @"SCTrustedTime" code: 3
                                                userInfo: @{NSLocalizedDescriptionKey: @"Pinned hosts disagree"}]);
            return;
        }
        NSDate* median = sorted[sorted.count / 2];
        BOOL ok = [median compare: threshold] != NSOrderedAscending;
        completion(ok, median, nil);
    });
}

@end
