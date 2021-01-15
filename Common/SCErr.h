//
//  SCErr.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/13/21.
//

#import <Foundation/Foundation.h>

// copied from StackOverflow answer by Wolfgang Schreurs: https://stackoverflow.com/a/14086231
#define SC_ERROR_KEY(code)                    [NSString stringWithFormat:@"%d", code]
#define SC_ERROR_LOCALIZED_DESCRIPTION(code)  NSLocalizedStringFromTable(SC_ERROR_KEY(code), @"SCError", nil)

FOUNDATION_EXPORT NSString * _Nonnull const kSelfControlErrorDomain;

NS_ASSUME_NONNULL_BEGIN

@interface SCErr : NSObject

+ (NSError*)errorWithCode:(int)errorCode subDescription:(NSString* _Nullable)subDescription;
+ (NSError*)errorWithCode:(int)errorCode;

@end

NS_ASSUME_NONNULL_END
