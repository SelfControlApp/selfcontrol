//
//  PreferencesGeneralViewController.h
//  SelfControl
//
//  Created by Charles Stigler on 9/27/14.
//
//

#import <Cocoa/Cocoa.h>
#import "MASPreferencesViewController.h"

@interface PreferencesGeneralViewController : NSViewController <MASPreferencesViewController>

@property (readonly) NSDictionary* securedSettingsDict;
@property IBOutlet NSDictionaryController* dictController;

- (IBAction)soundSelectionChanged:(id)sender;

@end
