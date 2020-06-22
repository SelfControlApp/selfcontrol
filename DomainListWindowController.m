
//
//  DomainListWindowController.m
//  SelfControl
//
//  Created by Charlie Stigler on 2/7/09.
//  Copyright 2009 Eyebeam.

// This file is part of SelfControl.
//
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "DomainListWindowController.h"
#import "SCUtilities.h"
#import "AppController.h"

@implementation DomainListWindowController

- (DomainListWindowController*)init {
	if(self = [super initWithWindowNibName:@"DomainList"]) {

		defaults_ = [NSUserDefaults standardUserDefaults];
        settings_ = [SCSettings currentUserSettings];

		NSArray* curArray = [settings_ valueForKey: @"Blocklist"];
		if(curArray == nil)
			domainList_ = [NSMutableArray arrayWithCapacity: 10];
		else
			domainList_ = [curArray mutableCopy];

		[settings_ setValue: domainList_ forKey: @"Blocklist"];
	}

	return self;
}
- (void)awakeFromNib  {
    NSInteger indexToSelect = [[settings_ valueForKey: @"BlockAsWhitelist"] boolValue] ? 1 : 0;
    [allowlistRadioMatrix_ selectCellAtRow: indexToSelect column: 0];
    
    [self updateWindowTitle];
}

- (void)showWindow:(id)sender {
	[[self window] makeKeyAndOrderFront: self];

	if ([domainList_ count] == 0) {
		[self addDomain: self];
	}
    
    [self updateWindowTitle];
}

- (IBAction)addDomain:(id)sender
{
	[domainList_ addObject:@""];
	[settings_ setValue: domainList_ forKey: @"Blocklist"];
	[domainListTableView_ reloadData];
	NSIndexSet* rowIndex = [NSIndexSet indexSetWithIndex: [domainList_ count] - 1];
	[domainListTableView_ selectRowIndexes: rowIndex
					  byExtendingSelection: NO];
	[domainListTableView_ editColumn: 0 row:([domainList_ count] - 1)
						   withEvent:nil
							  select:YES];
}

- (IBAction)removeDomain:(id)sender
{
	NSIndexSet* selected = [domainListTableView_ selectedRowIndexes];
	[domainListTableView_ abortEditing];

	// This isn't the most efficient way to do this, but the code is much cleaner
	// than other methods and the domain blocklist will probably never be large
	// enough for it to be an issue.
	NSUInteger index = [selected firstIndex];
	int shift = 0;
	while (index != NSNotFound) {
		if ((index - shift) >= [domainList_ count])
			break;
		[domainList_ removeObjectAtIndex: index - shift];
		shift++;
		index = [selected indexGreaterThanIndex: index];
	}

	[settings_ setValue: domainList_ forKey: @"Blocklist"];
	[domainListTableView_ reloadData];

	[[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
														object: self];
}

- (NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [domainList_ count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if (rowIndex < 0 || rowIndex + 1 > [domainList_ count]) return nil;
	return domainList_[rowIndex];
}

- (void)controlTextDidEndEditing:(NSNotification *)note {
	NSInteger editedRow = [domainListTableView_ editedRow];
	NSString* editedString = [[[[note userInfo] objectForKey: @"NSFieldEditor"] textStorage] string];
	editedString = [editedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if (![editedString length]) {
		NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex: editedRow];
		[domainListTableView_ beginUpdates];
		[domainListTableView_ removeRowsAtIndexes: indexSet withAnimation: NSTableViewAnimationSlideUp];
		[domainList_ removeObjectAtIndex: editedRow];
		[domainListTableView_ reloadData];
		[domainListTableView_ endUpdates];
		return;
	}
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(NSString*)newString
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex {
	if (rowIndex < 0 || rowIndex + 1 > [domainList_ count]) {
		return;
	}
    
    NSArray<NSString*>* cleanedEntries = [SCUtilities cleanBlocklistEntry: newString];
    
    for (int i = 0; i < cleanedEntries.count; i++) {
        NSString* entry = cleanedEntries[i];
        if (i == 0) {
            domainList_[rowIndex] = entry;
        } else {
            [domainList_ insertObject: entry atIndex: rowIndex + i];
        }
    }
    
    [settings_ setValue: domainList_ forKey: @"Blocklist"];
    [domainListTableView_ reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
    object: self];
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
			  row:(int)row {
	// this method is really inefficient. rewrite/optimize later.
	[defaults_ synchronize];

	// Initialize the cell's text color to black
	[cell setTextColor: NSColor.textColor];
	NSString* str = [[cell title] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if([str isEqual: @""]) return;
	if([defaults_ boolForKey: @"HighlightInvalidHosts"]) {
		// Validate the value as either an IP or a hostname.  In case of failure,
		// we'll make its text color red.

		int maskLength = -1;
		int portNum = -1;

		NSArray* splitString = [str componentsSeparatedByString: @"/"];

		str = [splitString[0] lowercaseString];

		NSString* stringToSearchForPort = str;

		if([splitString count] >= 2) {
			maskLength = [splitString[1] intValue];
			// If the int value is 0, we couldn't find a valid integer representation
			// in the split off string
			if(maskLength == 0)
				maskLength = -1;

			stringToSearchForPort = splitString[1];
		}

		splitString = [stringToSearchForPort componentsSeparatedByString: @":"];

		if(stringToSearchForPort == str) {
			str = splitString[0];
		}

		if([splitString count] >= 2) {
			portNum = [splitString[1] intValue];
			// If the int value is 0, we couldn't find a valid integer representation
			// in the split off string
			if(portNum == 0)
				portNum = -1;
		}

		BOOL isIP;

		NSString* ipValidationRegex = @"^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
		NSPredicate *ipRegexTester = [NSPredicate
									  predicateWithFormat:@"SELF MATCHES %@",
									  ipValidationRegex];
		isIP = [ipRegexTester evaluateWithObject: str];

		if(!isIP) {
			NSString* hostnameValidationRegex = @"^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,6}$";
			NSPredicate *hostnameRegexTester = [NSPredicate
												predicateWithFormat:@"SELF MATCHES %@",
												hostnameValidationRegex
												];

			if(![hostnameRegexTester evaluateWithObject: str] && ![str isEqualToString: @"*"] && ![str isEqualToString: @""]) {
				[cell setTextColor: NSColor.redColor];
				return;
			}
		}

		// We shouldn't have a mask length if it's not an IP, fail
		if(!isIP && maskLength != -1) {
			[cell setTextColor: NSColor.redColor];
			return;
		}

		if(([str isEqualToString: @"*"] || [str isEqualToString: @""]) && portNum == -1) {
			[cell setTextColor: NSColor.redColor];
			return;
		}

		[cell setTextColor: NSColor.textColor];
	}
}

- (IBAction)allowlistOptionChanged:(NSMatrix*)sender {
    switch (sender.selectedRow) {
        case 0:
            [settings_ setValue: @NO forKey: @"BlockAsWhitelist"];
            break;
        case 1:
            [self showAllowlistWarning];
            [settings_ setValue: @YES forKey: @"BlockAsWhitelist"];
            break;
    }
    
    // update UI to reflect appropriate list type
    AppController* controller = (AppController *)[NSApp delegate];
    [controller refreshUserInterface];
    [self updateWindowTitle];
}

- (void)showAllowlistWarning {
    if(![defaults_ boolForKey: @"WhitelistAlertSuppress"]) {
        NSAlert* a = [NSAlert alertWithMessageText: NSLocalizedString(@"Are you sure you want an allowlist block?", @"Allowlist block confirmation prompt") defaultButton: NSLocalizedString(@"OK", @"OK button") alternateButton: @"" otherButton: @"" informativeTextWithFormat: NSLocalizedString(@"An allowlist block means that everything on the internet BESIDES your specified list will be blocked.  This includes the web, email, SSH, and anything else your computer accesses via the internet.  If a web site requires resources such as images or scripts from a site that is not on your allowlist, the site may not work properly.", @"allowlist block explanation")];
        if([a respondsToSelector: @selector(setShowsSuppressionButton:)]) {
            [a setShowsSuppressionButton: YES];
        }
        [a runModal];
        if([a respondsToSelector: @selector(suppressionButton)] && [[a suppressionButton] state] == NSOnState) {
            [defaults_ setBool: YES forKey: @"WhitelistAlertSuppress"];
        }
    }
}

- (void)updateWindowTitle {
    NSString* listType = [[settings_ valueForKey: @"BlockAsWhitelist"] boolValue] ? @"Allowlist" : @"Blocklist";
    self.window.title = NSLocalizedString(([NSString stringWithFormat: @"Domain %@", listType]), @"Domain list window title");
}

- (void)addHostArray:(NSArray*)arr {
	for(int i = 0; i < [arr count]; i++) {
		// Check for dupes
		if(![domainList_ containsObject: arr[i]])
			[domainList_ addObject: arr[i]];
	}
	[settings_ setValue: domainList_ forKey: @"Blocklist"];
	[domainListTableView_ reloadData];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
														object: self];
}

- (IBAction)importCommonDistractingWebsites:(id)sender {
	[self addHostArray: [HostImporter commonDistractingWebsites]];
}
- (IBAction)importNewsAndPublications:(id)sender {
	[self addHostArray: [HostImporter newsAndPublications]];
}
- (IBAction)importIncomingMailServersFromThunderbird:(id)sender {
	[self addHostArray: [HostImporter incomingMailHostnamesFromThunderbird]];
}
- (IBAction)importOutgoingMailServersFromThunderbird:(id)sender {
	[self addHostArray: [HostImporter outgoingMailHostnamesFromThunderbird]];
}
- (IBAction)importIncomingMailServersFromMail:(id)sender {
	[self addHostArray: [HostImporter incomingMailHostnamesFromMail]];
}
- (IBAction)importOutgoingMailServersFromMail:(id)sender {
	[self addHostArray: [HostImporter outgoingMailHostnamesFromMail]];
}
- (IBAction)importIncomingMailServersFromMailMate:(id)sender {
	[self addHostArray: [HostImporter incomingMailHostnamesFromMailMate]];
}
- (IBAction)importOutgoingMailServersFromMailMate:(id)sender {
	[self addHostArray: [HostImporter outgoingMailHostnamesFromMailMate]];
}

@end
