//
//  SCXPCAuthorization.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/4/21.
//

#import "SCXPCAuthorization.h"

@implementation SCXPCAuthorization

// all of these methods (basically this whole file) copied from Apple's Even Better Authorization Sample code

static NSString * kCommandKeyAuthRightName    = @"authRightName";
static NSString * kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString * kCommandKeyAuthRightDesc    = @"authRightDescription";

static NSDictionary* kAuthorizationRuleAuthenticateAsAdmin2MinTimeout;

// copied from Apple's Even Better Authorization Sample code
+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
    // Check that the client denoted by authData is allowed to run the specified command.
    // authData is expected to be an NSData with an AuthorizationExternalForm embedded inside.
{
    #pragma unused(authData)
    AuthorizationRef            authRef;

    assert(command != nil);
    
    authRef = NULL;

    // First check that authData looks reasonable.
    if ( (authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)) ) {
        return [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    // Create an authorization ref from that the external form data contained within.
    OSStatus extFormStatus = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
    if (extFormStatus != errAuthorizationSuccess) {
        return [NSError errorWithDomain: NSOSStatusErrorDomain code: extFormStatus userInfo: nil];
    }

    // Authorize the right associated with the command.

    AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
    AuthorizationRights rights   = { 1, &oneRight };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;

    oneRight.name = [[SCXPCAuthorization authorizationRightForCommand:command] UTF8String];
    assert(oneRight.name != NULL);
    
    OSStatus authStatus = AuthorizationCopyRights(
        authRef,
        &rights,
        kAuthorizationEmptyEnvironment,
        flags,
        NULL
    );
    if (authRef != NULL) {
        AuthorizationFree(authRef, 0);
    }

    if (authStatus != errAuthorizationSuccess) {
        return [NSError errorWithDomain: NSOSStatusErrorDomain code: authStatus userInfo: nil];
    }

    return nil;
}


+ (NSDictionary *)commandInfo
{
    static dispatch_once_t sOnceToken;
    static NSDictionary *  sCommandInfo;
    
    // static var needs to bre defined before first use
    if (kAuthorizationRuleAuthenticateAsAdmin2MinTimeout == nil) {
        kAuthorizationRuleAuthenticateAsAdmin2MinTimeout = @{
            @"class": @"user",
            @"group": @"admin",
            @"timeout": @(120), // 2 minutes
            @"shared": @(YES),
            @"version": @1 // not entirely sure what this does TBH
        };
    }
    
    dispatch_once(&sOnceToken, ^{
        #pragma clang diagnostic ignored "-Wundeclared-selector"
        
        
        NSDictionary* startBlockCommandInfo = @{
            kCommandKeyAuthRightName    : @"org.eyebeam.SelfControl.startBlock",
            kCommandKeyAuthRightDefault : kAuthorizationRuleAuthenticateAsAdmin2MinTimeout,
            kCommandKeyAuthRightDesc    : NSLocalizedString(
                @"SelfControl needs your username and password to start the block.",
                @"prompt shown when user is required to authorize to start block"
            )
        };
        NSDictionary* modifyBlockCommandInfo = @{
            kCommandKeyAuthRightName    : @"org.eyebeam.SelfControl.modifyBlock",
            kCommandKeyAuthRightDefault : kAuthorizationRuleAuthenticateAsAdmin2MinTimeout,
            kCommandKeyAuthRightDesc    : NSLocalizedString(
                @"SelfControl needs your username and password to modify the block",
                @"prompt shown when user is required to authorize to modify their block"
            )
        };
        
        sCommandInfo = @{
            NSStringFromSelector(@selector(startBlockWithControllingUID:blocklist:isAllowlist:endDate:blockSettings:authorization:reply:)) : startBlockCommandInfo,
            NSStringFromSelector(@selector(updateBlocklist:authorization:reply:)) : modifyBlockCommandInfo,
            NSStringFromSelector(@selector(updateBlockEndDate:authorization:reply:)) : modifyBlockCommandInfo
            #pragma clang diagnostic pop
        };
    });
    return sCommandInfo;
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block
    // Calls the supplied block with information about each known authorization right..
{
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        #pragma unused(key)
        #pragma unused(stop)
        NSDictionary *  commandDict;
        NSString *      authRightName;
        id              authRightDefault;
        NSString *      authRightDesc;
        
        // If any of the following asserts fire it's likely that you've got a bug
        // in sCommandInfo.
        
        commandDict = (NSDictionary *) obj;
        assert([commandDict isKindOfClass:[NSDictionary class]]);

        authRightName = [commandDict objectForKey:kCommandKeyAuthRightName];
        assert([authRightName isKindOfClass:[NSString class]]);

        authRightDefault = [commandDict objectForKey:kCommandKeyAuthRightDefault];
        assert(authRightDefault != nil);

        authRightDesc = [commandDict objectForKey:kCommandKeyAuthRightDesc];
        assert([authRightDesc isKindOfClass:[NSString class]]);

        block(authRightName, authRightDefault, authRightDesc);
    }];
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef
    // See comment in header.
{
    assert(authRef != NULL);
    [SCXPCAuthorization enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
        OSStatus    blockErr;
        
        // First get the right.  If we get back errAuthorizationDenied that means there's
        // no current definition, so we add our default one.
        
        blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
        if (blockErr == errAuthorizationDenied) {
            NSLog(@"setting auth right default for %@: %@", authRightName, authRightDefault);
            blockErr = AuthorizationRightSet(
                authRef,                                    // authRef
                [authRightName UTF8String],                 // rightName
                (__bridge CFTypeRef) authRightDefault,      // rightDefinition
                (__bridge CFStringRef) authRightDesc,       // descriptionKey
                NULL,                                       // bundle (NULL implies main bundle)
                CFSTR("SCXPCAuthorization")                             // localeTableName
            );
            assert(blockErr == errAuthorizationSuccess);
        } else {
            // A right already exists (err == noErr) or any other error occurs, we
            // assume that it has been set up in advance by the system administrator or
            // this is the second time we've run.  Either way, there's nothing more for
            // us to do.
        }
    }];
}

+ (NSString *)authorizationRightForCommand:(SEL)command
    // See comment in header.
{
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
}


@end
