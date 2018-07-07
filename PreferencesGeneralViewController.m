//
//  PreferencesGeneralViewController.m
//  SelfControl
//
//  Created by Charles Stigler on 9/27/14.
//
//

#import "PreferencesGeneralViewController.h"
#import "SCSettings.h"
#import "SCConstants.h"

@interface PreferencesGeneralViewController ()

@end

@implementation PreferencesGeneralViewController

- (instancetype)init {
    return [super initWithNibName: @"PreferencesGeneralViewController" bundle: nil];
}

- (void)refreshBlockSoundFromSettings {
    SCSettings* settings = [SCSettings currentUserSettings];
    BOOL blockSoundShouldPlay = [[settings valueForKey: @"BlockSoundShouldPlay"] boolValue];
    NSInteger blockSoundIndex = [[settings valueForKey: @"BlockSound"] integerValue];
    
    self.playSoundCheckbox.state = blockSoundShouldPlay;
    [self.soundMenu selectItemAtIndex: blockSoundIndex];
    self.soundMenu.enabled = blockSoundShouldPlay;
}

- (void)viewDidLoad  {
    // set the valid sounds in the Block Sound menu
    [self.soundMenu removeAllItems];
    [self.soundMenu addItemsWithTitles: [SCConstants systemSoundNames]];
    
    [self refreshBlockSoundFromSettings];
}
- (void)viewDidAppear {
    [self refreshBlockSoundFromSettings];
}

- (IBAction)soundSelectionChanged:(NSPopUpButton*)sender {
	// Map the tags used in interface builder to the sound
    NSArray<NSString*>* systemSoundNames = [SCConstants systemSoundNames];
	
    NSString* selectedSoundName = sender.titleOfSelectedItem;
    NSInteger blockSoundIndex = [systemSoundNames indexOfObject: selectedSoundName];
    if (blockSoundIndex == NSNotFound) {
        NSLog(@"WARNING: User selected unknown alert sound %@.", selectedSoundName);
        NSError* err = [NSError errorWithDomain: @"SelfControlErrorDomain"
                                           code: -902
                                       userInfo: @{NSLocalizedDescriptionKey: @"Error -902: Unknown sound selected."}];
        [NSApp presentError: err];
        return;
    }
    [[SCSettings currentUserSettings] setValue: @(blockSoundIndex) forKey: @"BlockSound"];

    // now play the sound to preview it for the user
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

- (IBAction)soundCheckboxChanged:(NSButton*)sender {
    BOOL isChecked = (((NSButton*)sender).state == NSOnState);
    SCSettings* settings = [SCSettings currentUserSettings];
    
    if (sender == self.playSoundCheckbox) {
        [settings setValue: @(isChecked) forKey: @"BlockSoundShouldPlay"];
    }
    
    // enable the sound menu only if sound playback is enabled
    self.soundMenu.enabled = isChecked;
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
