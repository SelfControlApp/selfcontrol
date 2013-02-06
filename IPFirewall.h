//
//  IPFirewall.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/9/09.
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

#import <Foundation/Foundation.h>
#import <unistd.h>
#import "NSString+IPAddress.h"

// A class that represents the ipfw (ipfirewall) command-line firewall tool that
// comes installed on every Mac.  It has methods specifically for SelfControl to
// add and remove rules in SelfControl's specific rule "set", a division
// designed to make it easier to distinguish SelfControl rules and alter them
// separately from other ipfw rules.
@interface IPFirewall : NSObject {
  NSOperationQueue* opQueue;
  int selfControlBlockRuleCount_;
}

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, blocking all communications sent to the target
// destination port number.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleBlockingPort: (int) portNum;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, blocking the IP address represented by the NSString
// parameter.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleBlockingIP: (NSString*) ipAddress;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, blocking the IP address represented by the NSString
// parameter on the specified port.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleBlockingIP: (NSString*) ipAddress port:(int)portNum;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, blocking the IP range represented by the NSString
// parameter with the specified mask length.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleBlockingIP: (NSString*) ipAddress maskLength:(int)maskLength;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, blocking the IP range represented by the NSString
// parameter with the specified mask length on the specified port.  Returns the
// exit status code of ipfw.
- (void)addSelfControlBlockRuleBlockingIP: (NSString*) ipAddress port:(int)portNum maskLength:(int)maskLength;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, explicitly allowing all communications sent to the
// target destination port number.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleAllowingPort: (int) portNum;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, explicitly allowing the IP address represented by the NSString
// parameter.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleAllowingIP: (NSString*) ipAddress;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, explicitly allowing the IP address represented by the NSString
// parameter on the specified port.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleAllowingIP: (NSString*) ipAddress port:(int)portNum;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, explicitly allowing the IP range represented by the NSString
// parameter with the specified mask length.  Returns the exit status code of ipfw.
- (void)addSelfControlBlockRuleAllowingIP: (NSString*) ipAddress maskLength:(int)maskLength;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, explicitly allowing the IP range represented by the NSString
// parameter with the specified mask length on the specified port.  Returns the
// exit status code of ipfw.
- (void)addSelfControlBlockRuleAllowingIP: (NSString*) ipAddress port:(int)portNum maskLength:(int)maskLength;

// Calls the ipfw command-line tool to add a comment rule into the designated
// SelfControl ipfw rule set, containing a footer for the SelfControl block set.
// Returns the exit status code of ipfw.
- (void)addSelfControlBlockFooter;

// Calls the ipfw command-line tool to add a comment rule into the designated
// SelfControl ipfw rule set, containing a header for the SelfControl block set.
// The header also explicitly allows traffic on the loopback interface.
// Returns the exit status code of ipfw.
- (void)addSelfControlBlockHeader;

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, which stops all traffic and therefore when placed
// at the end of the SelfControl block set makes it a whitelist.
// Returns the exit status code of ipfw.
- (void)addWhitelistFooter;

// Calls the ipfw command-line tool to clear all rules in the designated
// SelfControl ipfw rule set.  Returns the exit status code of ipfw.
- (int)clearSelfControlBlockRuleSet;

// Calls the ipfw command-line tool to check, by checking the rule list for
// the SelfControl header, whether the SelfControl block set is loaded.  Returns
// the exit status code of ipfw.
- (BOOL)containsSelfControlBlockSet;

- (int)runFirewallCommand:(NSArray*)args;
- (void)enqueueFirewallCommand:(NSArray*)args;
- (void)waitUntilAllTasksExit;

@end