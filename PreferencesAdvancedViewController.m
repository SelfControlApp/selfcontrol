//
//  PreferencesAdvancedViewController.m
//  SelfControl
//
//  Created by Charles Stigler on 9/27/14.
//
//

#import "PreferencesAdvancedViewController.h"
#import "SCSettings.h"

@interface PreferencesAdvancedViewController ()

@end

@implementation PreferencesAdvancedViewController

- (instancetype)init {
	self = [super initWithNibName: @"PreferencesAdvancedViewController" bundle: nil];
    
    _securedSettingsDict = [SCSettings currentUserSettings];
    
    return self;
}

#pragma mark MASPreferencesViewController

- (NSString*)identifier {
	return @"AdvancedPreferences";
}
- (NSImage *)toolbarItemImage {
	return [NSImage imageNamed: NSImageNameAdvanced];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString(@"Advanced", @"Toolbar item name for the Advanced preference pane");
}

@end
