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
	return [super initWithNibName: @"PreferencesAdvancedViewController" bundle: nil];
}
    
- (void)refreshFromSecuredSettings {
    SCSettings* settings = [SCSettings currentUserSettings];
    BOOL clearCaches = [[settings valueForKey: @"ClearCaches"] boolValue];
    BOOL allowLocalNetworks = [[settings valueForKey: @"AllowLocalNetworks"] boolValue];
    BOOL evaluateCommonSubdomains = [[settings valueForKey: @"EvaluateCommonSubdomains"] boolValue];
    BOOL includeLinkedDomains = [[settings valueForKey: @"IncludeLinkedDomains"] boolValue];
    
    self.clearCachesCheckbox.state = clearCaches;
    self.allowLocalCheckbox.state = allowLocalNetworks;
    self.includeSubdomainsCheckbox.state = evaluateCommonSubdomains;
    self.includeLinkedSitesCheckbox.state = includeLinkedDomains;
}
    
- (IBAction)securedCheckboxChanged:(NSButton*)sender {
    BOOL isChecked = (((NSButton*)sender).state == NSOnState);
    SCSettings* settings = [SCSettings currentUserSettings];
    
    if (sender == self.clearCachesCheckbox) {
        [settings setValue: @(isChecked) forKey: @"ClearCaches"];
    } else if (sender == self.allowLocalCheckbox) {
        [settings setValue: @(isChecked) forKey: @"AllowLocalNetworks"];
    } else if (sender == self.includeSubdomainsCheckbox) {
        [settings setValue: @(isChecked) forKey: @"EvaluateCommonSubdomains"];
    } else if (sender == self.includeLinkedSitesCheckbox) {
        [settings setValue: @(isChecked) forKey: @"IncludeLinkedDomains"];
    }
}

- (void)viewDidLoad  {
    [self refreshFromSecuredSettings];
}
- (void)viewDidAppear {
    [self refreshFromSecuredSettings];
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
