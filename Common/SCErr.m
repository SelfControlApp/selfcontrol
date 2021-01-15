//
//  SCErr.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/13/21.
//

#import "SCErr.h"

NSString *const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@implementation SCErr

+ (NSError*)errorWithCode:(int)errorCode subDescription:(NSString  * _Nullable )subDescription {
    NSString* description = SC_ERROR_LOCALIZED_DESCRIPTION(errorCode);
    if (subDescription != nil) {
        description = [NSString stringWithFormat: description, subDescription];
    }

    return [NSError errorWithDomain: kSelfControlErrorDomain
                               code: errorCode
                           userInfo: @{
                               NSLocalizedDescriptionKey: description
                           }];
}

+ (NSError*)errorWithCode:(int)errorCode {
    return [SCErr errorWithCode: errorCode subDescription: nil];
}

@end
