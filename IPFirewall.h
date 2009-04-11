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

// A class that represents the ipfw (ipfirewall) command-line firewall tool that
// comes installed on every Mac.  It has methods specifically for SelfControl to
// add and remove rules in SelfControl's specific rule "set", a division
// designed to make it easier to distinguish SelfControl rules and alter them
// separately from other ipfw rules.
@interface IPFirewall : NSObject {
  int selfControlBlockRuleCount_;
}

// Calls the ipfw command-line tool to add a rule into the designated
// SelfControl ipfw rule set, blocking the IP address represented by the NSString
// parameter.  Returns the exit status code of ipfw.
- (int)addSelfControlBlockRuleBlockingIP: (NSString*) ipAddress;

// Calls the ipfw command-line tool to add a comment rule into the designated
// SelfControl ipfw rule set, containing a footer for the SelfControl block set.
// Returns the exit status code of ipfw.
- (int)addSelfControlBlockFooter;

// Calls the ipfw command-line tool to add a comment rule into the designated
// SelfControl ipfw rule set, containing a header for the SelfControl block set.
// Returns the exit status code of ipfw.
- (int)addSelfControlBlockHeader;

// Calls the ipfw command-line tool to clear all rules in the designated
// SelfControl ipfw rule set.  Returns the exit status code of ipfw.
- (int)clearSelfControlBlockRuleSet;

// Calls the ipfw command-line tool to check, by checking the rule list for
// the SelfControl header, whether the SelfControl block set is loaded.  Returns
// the exit status code of ipfw.
- (BOOL)containsSelfControlBlockSet;

@end