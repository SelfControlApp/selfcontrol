#import "SCPinnedHosts.h"

@implementation SCPinnedHosts

+ (NSArray<NSDictionary<NSString*, NSString*>*>*)hosts {
    static NSArray* hosts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        hosts = @[
            @{ @"host": @"www.apple.com",      @"spki": @"tkhcoCq9fS0kxe9haZp9eTXk4I3DHivWzpKuZ20xLL8=" },
            @{ @"host": @"www.google.com",     @"spki": @"CQ2Nf4E/Y0gbNWpUYCT2Ts/sXNq97QmWr5Yfe6T6cR8=" },
            @{ @"host": @"www.cloudflare.com", @"spki": @"InW7U3grEKRuwhErwsI/XULSUbEWmteQprf4vp8Oo7Y=" },
        ];
    });
    return hosts;
}

@end
