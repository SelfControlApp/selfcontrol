//
//  SCBlockEntry.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/20/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCBlockEntry : NSObject

@property (nonatomic) NSString* hostname;
@property (nonatomic) NSInteger port;
@property (nonatomic) NSInteger maskLen;

+ (instancetype)entryWithHostname:(NSString*)hostname;
+ (instancetype)entryWithHostname:(NSString*)hostname port:(NSInteger)port maskLen:(NSInteger)maskLen;
+ (instancetype)entryFromString:(NSString*)domainString;

- (BOOL)isEqualToEntry:(SCBlockEntry*)otherEntry;

@end

NS_ASSUME_NONNULL_END
