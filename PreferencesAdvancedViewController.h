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

@property IBOutlet NSButton* clearCachesCheckbox;
@property IBOutlet NSButton* allowLocalCheckbox;
@property IBOutlet NSButton* includeSubdomainsCheckbox;
@property IBOutlet NSButton* includeLinkedSitesCheckbox;
    
@end
