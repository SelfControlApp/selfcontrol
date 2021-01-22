//
//  SCBlockEntry.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/20/21.
//

#import "SCBlockEntry.h"

@implementation SCBlockEntry

- (instancetype)init {
    return [self initWithHostname: nil port: 0 maskLen: 0];
}
- (instancetype)initWithHostname:(NSString*)hostname {
    return [self initWithHostname: hostname port: 0 maskLen: 0];
}
- (instancetype)initWithHostname:(NSString*)hostname port:(NSInteger)port maskLen:(NSInteger)maskLen {
    if (self = [super init]) {
        _hostname = hostname;
        _port = port;
        _maskLen = maskLen;
    }
    return self;
}

+ (instancetype)entryWithHostname:(NSString*)hostname port:(NSInteger)port maskLen:(NSInteger)maskLen {
    return [[SCBlockEntry alloc] initWithHostname: hostname port: port maskLen: maskLen];
}

+ (instancetype)entryWithHostname:(NSString*)hostname {
    return [[SCBlockEntry alloc] initWithHostname: hostname];
}

+ (instancetype)entryFromString:(NSString*)hostString {
    // don't do anything with blank hostnames, however they got on the list...
    // otherwise they could end up screwing up the block
    if (![[hostString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
        return nil;
    }

    NSString* hostname;
    // returning 0 for either of these values means "couldn't find it in the string"
    int maskLen = 0;
    int port = 0;

    NSArray* splitString = [hostString componentsSeparatedByString: @"/"];
    hostname = splitString[0];

    NSString* stringToSearchForPort = splitString[0];

    if([splitString count] >= 2) {
        maskLen = [splitString[1] intValue];

        // we expect the port number to come after the IP/masklen
        stringToSearchForPort = splitString[1];
    }

    splitString = [stringToSearchForPort componentsSeparatedByString: @":"];

    // only if hostName wasn't already split off by the maskLen
    if([stringToSearchForPort isEqualToString: hostname]) {
        hostname = splitString[0];
    }

    if([splitString count] >= 2) {
        port = [splitString[1] intValue];
    }

    if([hostname isEqualToString: @""]) {
        hostname = @"*";
    }

    // we won't block host * (everywhere) without a port number... it's just too likely to be mistaken.
    // Use a allowlist if that's what you want!
    if ([hostname isEqualToString: @"*"] && !port) {
        return nil;
    }
    
    return [SCBlockEntry entryWithHostname: hostname port: port maskLen: maskLen];
}

- (NSString*)description {
    return [NSString stringWithFormat: @"[Entry: hostname = %@, port = %ld, maskLen = %ld]", self.hostname, (long)self.port, (long)self.maskLen];
}

// method implementations of isEqual, isEqualToEntry, and hash are based on this answer from StackOverflow: https://stackoverflow.com/q/254281

- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass: [self class]])
        return NO;
    return [self isEqualToEntry: other];
}

- (BOOL)isEqualToEntry:(SCBlockEntry*)otherEntry {
    if (otherEntry == nil) return NO;
    if (self == otherEntry) return YES;
    
    if ([self.hostname isEqualToString: otherEntry.hostname] && self.port == otherEntry.port && self.maskLen == otherEntry.maskLen) {
        return YES;
    } else {
        return NO;
    }
}

- (NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;
    
    if (self.hostname == nil) {
        result = prime * result;
    } else {
        result = prime * result + [self.hostname hash];
    }

    result = prime * result + (NSUInteger)self.port;
    result = prime * result + (NSUInteger)self.maskLen;

    return result;
}

@end
