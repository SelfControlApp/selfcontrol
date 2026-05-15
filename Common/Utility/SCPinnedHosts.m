#import "SCPinnedHosts.h"

@implementation SCPinnedHosts

+ (NSArray<NSDictionary<NSString*, NSString*>*>*)hosts {
    static NSArray* hosts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Pins are SHA-256 (base64) of SecKeyCopyExternalRepresentation() output
        // for the leaf certificate's public key — i.e., the raw public-key bytes
        // (RSA modulus+exponent, or EC point), NOT the full ASN.1 SPKI.
        // To recompute, see the SCTrustedTime pinning delegate in SCTrustedTime.m.
        hosts = @[
            @{ @"host": @"www.apple.com",      @"spki": @"vGYr5lNKlPJ0wSZMROTsiP+dd8iCbBOe7YZMVoy4cK0=" },
            @{ @"host": @"www.google.com",     @"spki": @"u6g6X+7KXDBCQ91pQEWODwB8+hbZW43/7pbjYIAzpNU=" },
            @{ @"host": @"www.cloudflare.com", @"spki": @"b1g23yk9nBZr6VXWRfLBYuSS/kzvrmf565y9Cs+3sNw=" },
        ];
    });
    return hosts;
}

@end
