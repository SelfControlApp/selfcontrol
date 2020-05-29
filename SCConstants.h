//
//  SCConstants.h
//  SelfControl
//
//  Created by Charlie Stigler on 3/31/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSelfControlErrorDomain;

@interface SCConstants : NSObject

+ (NSArray<NSString*>*) systemSoundNames;

@end

NS_ASSUME_NONNULL_END
