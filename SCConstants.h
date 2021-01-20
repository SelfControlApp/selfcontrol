//
//  SCConstants.h
//  SelfControl
//
//  Created by Charlie Stigler on 3/31/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

OSStatus const AUTH_CANCELLED_STATUS = -60006;

@interface SCConstants : NSObject

@property (class, readonly, nonatomic) NSArray<NSString*>* systemSoundNames;
@property (class, readonly, nonatomic) NSDictionary<NSString*, id>* const defaultUserDefaults;

@end

NS_ASSUME_NONNULL_END
