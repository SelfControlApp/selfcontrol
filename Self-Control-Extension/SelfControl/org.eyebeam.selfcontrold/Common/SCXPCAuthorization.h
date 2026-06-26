//
//  SCXPCAuthorization.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/4/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCXPCAuthorization : NSObject

+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command;

+ (NSString *)authorizationRightForCommand:(SEL)command;
    // For a given command selector, return the associated authorization right name.

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef;
    // Set up the default authorization rights in the authorization database.

@end

NS_ASSUME_NONNULL_END
