//
//  SCLockFileUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 20/10/2018.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCSettings : NSObject

+ (NSDictionary*)settingsDictionary;
+ (void)reloadSettings;
+ (void)synchronizeSettings;
+ (void)setValue:(id)value forKey:(NSString*)key;
+ (id)getValueForKey:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
