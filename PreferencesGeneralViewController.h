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

@property IBOutlet NSButton* playSoundCheckbox;
@property IBOutlet NSPopUpButton* soundMenu;

- (IBAction)soundSelectionChanged:(id)sender;

@end
