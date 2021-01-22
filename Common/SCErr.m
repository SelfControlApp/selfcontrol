//
//  SCErr.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/13/21.
//

#import "SCErr.h"

NSString *const kSelfControlErrorDomain = @"SelfControlErrorDomain";

@implementation SCErr

+ (NSError*)errorWithCode:(NSInteger)errorCode subDescription:(NSString  * _Nullable )subDescription {
    BOOL descriptionNotFound = NO;
    NSString* description = SC_ERROR_LOCALIZED_DESCRIPTION(errorCode);
    
    // if we couldn't find a localized description key, that probably means
    // we're in the daemon or somewhere else where .strings aren't available.
    // flag that so the app can fill in the details later
    if ([description isEqualToString: SC_ERROR_KEY(errorCode)]) {
        description = [NSString stringWithFormat: @"SelfControl hit an unknown error with code %ld.", errorCode];
        descriptionNotFound = YES;
    }

    if (subDescription != nil) {
        description = [NSString stringWithFormat: description, subDescription];
    }

    return [NSError errorWithDomain: kSelfControlErrorDomain
                               code: errorCode
                           userInfo: @{
                               NSLocalizedDescriptionKey: description,
                               @"SCDescriptionNotFound": @(descriptionNotFound)
                           }];
}

+ (NSError*)errorWithCode:(NSInteger)errorCode {
    return [SCErr errorWithCode: errorCode subDescription: nil];
}

@end
