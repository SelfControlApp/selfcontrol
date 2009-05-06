//
//  IPFirewall.m
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

#import "IPFirewall.h"

NSString* const kIPFirewallExecutablePath = @"/sbin/ipfw";
int const kIPFirewallRuleSetNumber = 19;
int const kIPFirewallRuleStartNumber = 1500;
NSString* const kIPFirewallSelfControlHeader = @"// BEGIN SELFCONTROL BLOCK";
NSString* const kIPFirewallSelfControlFooter = @"// END SELFCONTROL BLOCK";

@implementation IPFirewall

- (int)addSelfControlBlockRuleBlockingIP:(NSString*)ipAddress {    
  NSArray* hostAndPort = [ipAddress componentsSeparatedByString:@":"];
  NSString* hostToBeBlocked = [hostAndPort objectAtIndex: 0];
  NSString* portToBeBlocked = nil;
  if([hostAndPort count] > 1) {
    portToBeBlocked = [hostAndPort objectAtIndex: 1];
  }
  NSArray* args = [NSArray array];
  if(portToBeBlocked == nil) {
    args = [NSArray arrayWithObjects:
                     @"-q",
                     @"add",
                     [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                     @"set",
                     [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                     @"deny",
                     @"ip",
                     @"from",
                     @"me",
                     @"to",
                     [NSString stringWithString: hostToBeBlocked],
                     nil];
  }
  else {
    args = [NSArray arrayWithObjects:
                     @"-q",
                     @"add",
                     [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                     @"set",
                     [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                     @"deny",
                     @"ip",
                     @"from",
                     @"me",
                     @"to",
                     [NSString stringWithString: hostToBeBlocked],
                     @"dst-port",
                     [NSString stringWithString: portToBeBlocked],
                     nil];
  }
      
  NSTask* task = [NSTask launchedTaskWithLaunchPath: kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  // We have to keep track of how many rules we've used to we know at what number
  // to insert new rules.
  selfControlBlockRuleCount_++;
  
  return status;
}

- (int)addSelfControlBlockRuleAllowingIP:(NSString*)ipAddress {    
  NSArray* hostAndPort = [ipAddress componentsSeparatedByString:@":"];
  NSString* hostToBeAllowed = [hostAndPort objectAtIndex: 0];
  NSString* portToBeAllowed = nil;
  if([hostAndPort count] > 1) {
    portToBeAllowed = [hostAndPort objectAtIndex: 1];
  }
  NSArray* args = [NSArray array];
  if(portToBeAllowed == nil) {
    args = [NSArray arrayWithObjects:
            @"-q",
            @"add",
            [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
            @"set",
            [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
            @"allow",
            @"ip",
            @"from",
            @"me",
            @"to",
            [NSString stringWithString: hostToBeAllowed],
            nil];
  }
  else {
    args = [NSArray arrayWithObjects:
            @"-q",
            @"add",
            [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
            @"set",
            [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
            @"allow",
            @"ip",
            @"from",
            @"me",
            @"to",
            [NSString stringWithString: hostToBeAllowed],
            @"dst-port",
            [NSString stringWithString: portToBeAllowed],
            nil];
  }
  
  NSTask* task = [NSTask launchedTaskWithLaunchPath: kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  // We have to keep track of how many rules we've used to we know at what number
  // to insert new rules.
  selfControlBlockRuleCount_++;
  
  return status;
}

- (int)addWhitelistFooter {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"allow",
                   @"udp",
                   @"from",
                   @"me",
                   @"to",
                   @"any",
                   @"dst-port",
                   @"53",
                   nil];
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  selfControlBlockRuleCount_++;
    
  args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"deny",
                   @"ip",
                   @"from",
                   @"me",
                   @"to",
                   @"any",
                   nil];
  task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  status = [task terminationStatus] && status;
  
  selfControlBlockRuleCount_++;
  
  return status;  
}

- (int)addSelfControlBlockHeader {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"//",
                   @"BEGIN",
                   @"SELFCONTROL",
                   @"BLOCK",
                   nil];
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  selfControlBlockRuleCount_++;

  // This adds a rule to allow any traffic coming on the loopback interface, this
  // is necessary because if we accidentally blocked localhost it would make the
  // computer go crazy.
  args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"allow",
                   @"ip",
                   @"from",
                   @"any",
                   @"to",
                   @"any",
                   @"via",
                   @"lo*",
                   nil];
  task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  status = [task terminationStatus] && status;
  
  selfControlBlockRuleCount_++;  
  
  return status;
}

- (int)addSelfControlBlockFooter {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + selfControlBlockRuleCount_],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"//",
                   @"END",
                   @"SELFCONTROL",
                   @"BLOCK",
                   nil];                   
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  selfControlBlockRuleCount_++;
  
  return status;
}

- (int)clearSelfControlBlockRuleSet {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"delete",
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   nil];
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath
                                          arguments:args];
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  return status;
}

- (BOOL)containsSelfControlBlockSet {
  NSTask* task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:kIPFirewallExecutablePath];
  NSArray* args = [NSArray arrayWithObjects: @"-S", @"show", nil];
  [task setArguments:args];
  NSPipe* inPipe = [[[NSPipe alloc] init] autorelease];
  NSFileHandle* readHandle = [inPipe fileHandleForReading];
  [task setStandardOutput: inPipe];
  [task launch];
  NSString* ruleList = [[[NSString alloc] initWithData:[readHandle readDataToEndOfFile]
                                              encoding: NSUTF8StringEncoding] autorelease];
  close([readHandle fileDescriptor]);
  [task waitUntilExit];
  int status = [task terminationStatus];
  
  if(status != 0 || !ruleList)
    return NO;
  
  return [ruleList rangeOfString: kIPFirewallSelfControlHeader].location != NSNotFound;
}

@end