//
//  DomainListWindowController.h
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


#import <Cocoa/Cocoa.h>
#import "HostImporter.h"
#import "ThunderbirdPreferenceParser.h"
#import "SCSettings.h"

// A subclass of NSWindowController created to manage the domain list (actually
// host list, but domain list seems more understandable to inexperienced users
// and experienced users will figure out they can put in IP addresses) window,
// and the table view it contains.
@interface DomainListWindowController : NSWindowController {
	NSMutableArray* domainList_;
	IBOutlet NSTableView* domainListTableView_;
    IBOutlet NSMatrix* allowlistRadioMatrix_;
	NSUserDefaults* defaults_;
}

@property (getter=isReadOnly) BOOL readOnly;

- (void)refreshDomainList;

// Called when the add button is clicked.  Adds a new empty string to the domain
// list, reloads the table view, and highlights and opens that cell for editing.
- (IBAction)addDomain:(id)sender;

// Called when the remove button is clicked (or when the delete key is pressed,
// which just maps to the remove button).  Deletes all selected rows and reloads
// the table view.  Sends a SCConfigurationChangedNotification.
- (IBAction)removeDomain:(id)sender;

// Called by the table view on it's data source object (this) to determine how
// many rows are in the table view to be displayed.  Returns the number of
// objects in the domain list array.
- (NSUInteger)numberOfRowsInTableView:(NSTableView *)aTableView;

// Called by the table view on it's data source object (this) to determine what
// value should be displayed for a given row index.  Returns the corresponding
// value from the domain list array.
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

// Called by the table view on it's data source object (this) to set the value
// of the cell at a given row index.  Sets the value of the corresponding object
// in the domain list array and reloads the table view.  Sends a
// SCConfigurationChangedNotification.
- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)theObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(NSInteger)rowIndex;

// Called by the table view on it's data source object (this) when a given cell
// is about to be displayed.  Used to implement invalid domain highlighting if
// the user has chosen to enable it.
- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
			  row:(int)row;

- (IBAction)allowlistOptionChanged:(NSMatrix*)sender;
- (void)showAllowlistWarning;

- (IBAction)importCommonDistractingWebsites:(id)sender;
- (IBAction)importNewsAndPublications:(id)sender;

// Called when the button-menu item is clicked to import all incoming mail
// servers from Thunderbird.  Adds to the domain list array all incoming mail
// servers from the Thunderbird default profile that haven't already been added,
// and reloads the table view.  Sends a SCConfigurationChangedNotification.
- (IBAction)importIncomingMailServersFromThunderbird:(id)sender;

// Called when the button-menu item is clicked to import all outgoing mail
// servers from Thunderbird.  Adds to the domain list array all outgoing mail
// servers from the Thunderbird default profile that haven't already been added,
// and reloads the table view.  Sends a SCConfigurationChangedNotification.
- (IBAction)importOutgoingMailServersFromThunderbird:(id)sender;

// Called when the button-menu item is clicked to import all incoming mail
// servers from Mail.app.  Adds to the domain list array all incoming mail
// servers Mail.app that haven't already been added, and reloads the table view.
// Sends a SCConfigurationChangedNotification.
- (IBAction)importIncomingMailServersFromMail:(id)sender;

// Called when the button-menu item is clicked to import all outgoing mail
// servers from Mail.app.  Adds to the domain list array all outgoing mail
// servers Mail.app that haven't already been added, and reloads the table view.
// Sends a SCConfigurationChangedNotification.
- (IBAction)importOutgoingMailServersFromMail:(id)sender;

- (IBAction)importIncomingMailServersFromMailMate:(id)sender;
- (IBAction)importOutgoingMailServersFromMailMate:(id)sender;

@end
