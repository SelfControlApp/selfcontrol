//
//  PreferencesGeneralViewController.m
//  SelfControl
//
//  Created by Charles Stigler on 9/27/14.
//
//

#import "PreferencesGeneralViewController.h"

@interface PreferencesGeneralViewController ()

@end

@implementation PreferencesGeneralViewController

- (instancetype)init {
	return [super initWithNibName: @"PreferencesGeneralViewController" bundle: nil];
}

- (IBAction)soundSelectionChanged:(id)sender {
	// Map the tags used in interface builder to the sound
	NSArray* systemSoundNames = @[@"Basso",
								  @"Blow",
								  @"Bottle",
								  @"Frog",
								  @"Funk",
								  @"Glass",
								  @"Hero",
								  @"Morse",
								  @"Ping",
								  @"Pop",
								  @"Purr",
								  @"Sosumi",
								  @"Submarine",
								  @"Tink"];
	NSInteger blockSoundIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"BlockSound"];
	NSSound* alertSound = [NSSound soundNamed: systemSoundNames[blockSoundIndex]];
	if(!alertSound) {
		NSLog(@"WARNING: Alert sound not found.");
		NSError* err = [NSError errorWithDomain: @"SelfControlErrorDomain"
										   code: -901
									   userInfo: @{NSLocalizedDescriptionKey: @"Error -901: Selected sound not found."}];
		[NSApp presentError: err];
	} else {
		[alertSound play];
	}
}

#pragma mark MASPreferencesViewController

- (NSString*)identifier {
	return @"GeneralPreferences";
}
- (NSImage *)toolbarItemImage {
	return [NSImage imageNamed: NSImageNamePreferencesGeneral];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString(@"General", @"Toolbar item name for the General preference pane");
}

@end
