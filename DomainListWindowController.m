
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

@implementation DomainListWindowController

- (DomainListWindowController*)init {
  self = [super initWithWindowNibName:@"DomainList"];
  
 // [domainListTableView_ retain];
  
  defaults_ = [NSUserDefaults standardUserDefaults];
  
  NSArray* curArray = [defaults_ arrayForKey: @"HostBlacklist"];
  if(curArray == nil)
    domainList_ = [NSMutableArray arrayWithCapacity: 10];
  else
    domainList_ = [curArray mutableCopy];
    
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  
  return self;
}

- (IBAction)addDomain:(id)sender
{
  [domainList_ addObject:@""];
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [domainListTableView_ reloadData];
  [domainListTableView_ selectRow:([domainList_ count] - 1)
             byExtendingSelection:NO];
  [domainListTableView_ editColumn: 0 row:([domainList_ count] - 1)
                         withEvent:nil
                            select:YES];
}

- (IBAction)removeDomain:(id)sender
{
  NSIndexSet* selected = [domainListTableView_ selectedRowIndexes];
  
  // This isn't the most efficient way to do this, but the code is much cleaner
  // than other methods and the domain blacklist will probably never be large
  // enough for it to be an issue.
  unsigned int index = [selected firstIndex];
  int shift = 0;
  while (index != NSNotFound) {
    if (index < 0 || (index - shift) >= [domainList_ count])
      break;
    [domainList_ removeObjectAtIndex: index - shift];
    shift++;
    index = [selected indexGreaterThanIndex: index];
  }
  
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [domainListTableView_ reloadData];
  
  [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                      object: nil];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [domainList_ count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
  return [domainList_ objectAtIndex:rowIndex];
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)theObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(int)rowIndex {
  // All of this is just code to standardize and clean up the input value.
  // This'll remove whitespace and lowercase the string.
  NSString* str = [[theObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
  
  // Remove "http://" if a user tried to put that in
  NSArray* splitString = [str componentsSeparatedByString: @"http://"];
  for(int i = 0; i < [splitString count]; i++) {
    if(![[splitString objectAtIndex: i] isEqual: @""]) {
      str = [splitString objectAtIndex: i];
      break;
    }
  }
  
  // Delete anything after a "/" in case a user tried to copy-paste a web address.
  str = [[str componentsSeparatedByString: @"/"] objectAtIndex: 0];
  if([str isEqual: @""])
    [domainList_ removeObjectAtIndex: rowIndex];
  else
    [domainList_ replaceObjectAtIndex:rowIndex withObject:str];
  
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [aTableView reloadData];
  [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                      object: nil];  
}

/* - (NSCell *)tableView:(NSTableView*)tableView
dataCellForTableColumn:(NSTableColumn *)tableColumn
                  row:(int)row {
  NSTextFieldCell *cell = [tableColumn dataCell];
  
  if(row == 0) {
    [cell setTextColor: [NSColor redColor]];
  } else {
    [cell setTextColor: [NSColor blackColor]];
  }
  
  return cell;
  
} */

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(int)row {
  // this method is really inefficient.   rewrite/optimize latter.
  [defaults_ synchronize];
  
  // Initialize the cell's text color to black
  [cell setTextColor: [NSColor blackColor]];
  NSString* str = [[cell title] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if([str isEqual: @""]) return;
  if([defaults_ boolForKey: @"HighlightInvalidHosts"]) {
    // Validate the value as either an IP or a hostname.  In case of failure,
    // we'll make its text color red.
    NSArray* parts = [str componentsSeparatedByString:@":"];
    str = [parts objectAtIndex: 0];
    NSString* hostnameValidationRegex = @"^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,6}$";
    NSPredicate *hostnameRegexTester = [NSPredicate
                                        predicateWithFormat:@"SELF MATCHES %@",
                                        hostnameValidationRegex
                                       ];
    if ([hostnameRegexTester evaluateWithObject:str] != YES) {
      NSString* ipValidationRegex = @"^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
      NSPredicate *ipRegexTester = [NSPredicate
                                    predicateWithFormat:@"SELF MATCHES %@",
                                    ipValidationRegex];
      if ([ipRegexTester evaluateWithObject:str] != YES) {
        [cell setTextColor: [NSColor redColor]];
      } else
        [cell setTextColor: [NSColor blackColor]];
    } else
      if([parts count] > 1 && ([[parts objectAtIndex: 1] intValue] < 0 || [[parts objectAtIndex: 1] intValue] > 65536))
        [cell setTextColor: [NSColor redColor]];
      else
        [cell setTextColor: [NSColor blackColor]];
  } else
    [cell setTextColor: [NSColor blackColor]];
}

- (IBAction)importIncomingMailServersFromThunderbird:(id)sender {
  NSArray* arr = [HostImporter incomingMailHostnamesFromThunderbird];
  for(int i = 0; i < [arr count]; i++) {
    // Check for dupes
    if(![domainList_ containsObject: [arr objectAtIndex: i]])
      [domainList_ addObject: [arr objectAtIndex: i]];
  }
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [domainListTableView_ reloadData];
  [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                      object: nil];
}

- (IBAction)importOutgoingMailServersFromThunderbird:(id)sender {
  NSArray* arr = [HostImporter outgoingMailHostnamesFromThunderbird];
  for(int i = 0; i < [arr count]; i++) {
    // Check for dupes
    if(![domainList_ containsObject: [arr objectAtIndex: i]])
      [domainList_ addObject: [arr objectAtIndex: i]];
  }
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [domainListTableView_ reloadData];
  [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                      object: nil];
}


- (IBAction)importIncomingMailServersFromMail:(id)sender {
  NSArray* arr = [HostImporter incomingMailHostnamesFromMail];
  for(int i = 0; i < [arr count]; i++) {
    // Check for dupes
    if(![domainList_ containsObject: [arr objectAtIndex: i]])
      [domainList_ addObject: [arr objectAtIndex: i]];
  }
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [domainListTableView_ reloadData];
  [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                      object: nil];
}


- (IBAction)importOutgoingMailServersFromMail:(id)sender {
  NSArray* arr = [HostImporter outgoingMailHostnamesFromMail];
  for(int i = 0; i < [arr count]; i++) {
    // Check for dupes
    if(![domainList_ containsObject: [arr objectAtIndex: i]])
      [domainList_ addObject: [arr objectAtIndex: i]];
  }
  [defaults_ setObject: domainList_ forKey: @"HostBlacklist"];
  [domainListTableView_ reloadData];
  [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
                                                      object: nil];
}

- (void)dealloc {
 // [domainListTableView_ release];
  [super dealloc];
}

@end