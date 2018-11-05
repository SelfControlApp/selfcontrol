//
//  SCLockFileUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 20/10/2018.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCSettings : NSObject

@property (readonly) uid_t userId;
@property (readonly) NSDictionary* settingsDictionary;

+ (instancetype)currentUserSettings;
+ (instancetype)settingsForUser:(uid_t)uid;

- (NSString*)lockFilePath;
- (NSString*)securedSettingsFilePath;

- (void)reloadSettings;
- (void)writeSettings;
- (void)synchronizeSettings;
- (void)setValue:(id)value forKey:(NSString*)key;
- (id)getValueForKey:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
