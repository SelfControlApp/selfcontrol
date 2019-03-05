//
//  SCLockFileUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 20/10/2018.
//

#import <Foundation/Foundation.h>
#import "SelfControlCommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCSettings : NSObject

@property (readonly) uid_t userId;
@property (readonly) NSDictionary* dictionaryRepresentation;

+ (instancetype)currentUserSettings;
+ (instancetype)settingsForUser:(uid_t)uid;

- (NSString*)lockFilePath;
- (NSString*)securedSettingsFilePath;

- (void)reloadSettings;
- (void)writeSettings;
- (void)synchronizeSettings;
- (void)setValue:(nullable id)value forKey:(NSString*)key;
- (id)valueForKey:(NSString*)key;
- (void)migrateLegacySettings;
- (void)clearLegacySettings;

@end

NS_ASSUME_NONNULL_END
