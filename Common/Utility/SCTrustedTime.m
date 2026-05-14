#import "SCTrustedTime.h"

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

@end
