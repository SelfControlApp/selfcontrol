//
//  PreferencesAdvancedViewController.h
//  SelfControl
//
//  Created by Charles Stigler on 9/27/14.
//
//

#import <Cocoa/Cocoa.h>
#import "MASPreferencesViewController.h"

@interface PreferencesAdvancedViewController : NSViewController <MASPreferencesViewController>

@property (readonly) NSDictionary* securedSettingsDict;

@end
