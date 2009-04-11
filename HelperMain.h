//
//  HelperMain.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/4/09.
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
#import "IPFirewall.h"
#import "LaunchctlHelper.h"
#import <unistd.h>

// The main class for SelfControl's helper tool to be run by launchd with high
// privileges in order to handle the root-only configuration.

// These don't comply with the "end instance variables with an underscore" rule
// because they aren't instance variables.  Note this file is, although in
// Objective-C, not a class.  It contains only functions.
NSUserDefaults* defaults;
NSArray* domainList;

// The main method which deals which most of the logic flow and execution of 
// the helper tool.  Posts an SCConfigurationChangedNotification if the block
// is enabled or disabled.
int main(int argc, char* argv[]);

// Reads the domain block list from the defaults for SelfControl, and adds deny
// rules for all of the IPs (or the A DNS record IPS for doamin names) to the
// ipfw firewall.
void addRulesToFirewall();

// Removes from ipfw all rules that were created by SelfControl.
void removeRulesFromFirewall();

// Returns an autoreleased NSSet containing all IP adresses for evaluated
// "common subdomains" for the specified hostname
NSSet* getEvaluatedHostNamesFromCommonSubdomains(NSString* hostName, NSString* port);