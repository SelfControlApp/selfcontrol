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

- (IPFirewall*)init {
  if(self = [super init]) {
    allTasks = [NSMutableArray array];
    taskLock = [[[NSLock alloc] init] autorelease];
  }
  
  return self;
}

/* Port blocking/allowing methods */

- (void)addSelfControlBlockRuleBlockingPort:(int)portNum {
  NSArray* args = [NSArray array];
  args = [NSArray arrayWithObjects:
          @"-q",
          @"add",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
          @"set",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
          @"deny",
          @"ip",
          @"from",
          @"me",
          @"to",
          @"any",
          @"dst-port",
          [NSString stringWithFormat: @"%d", portNum],
          nil];
  
  NSTask* task = [NSTask launchedTaskWithLaunchPath: kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
}

- (void)addSelfControlBlockRuleAllowingPort:(int)portNum {
  NSArray* args = [NSArray array];
  args = [NSArray arrayWithObjects:
          @"-q",
          @"add",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
          @"set",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
          @"allow",
          @"ip",
          @"from",
          @"any",
          @"to",
          @"any",
          @"dst-port",
          [NSString stringWithFormat: @"%d", portNum],
          nil];
  
  NSTask* task = [NSTask launchedTaskWithLaunchPath: kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
}

/* IP blocking/allowing methods */

- (void)addSelfControlBlockRuleBlockingIP:(NSString*)ipAddress port:(int)portNum maskLength:(int)maskLength {
  NSString* blockString = [NSString stringWithString: ipAddress];
  if(maskLength) {
    blockString = [NSString stringWithFormat: @"%@/%d", ipAddress, maskLength];
  }
  
  NSArray* args = [NSArray array];
  args = [NSArray arrayWithObjects:
          @"-q",
          @"add",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
          @"set",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
          @"deny",
          @"ip",
          @"from",
          @"me",
          @"to",
          blockString,
          nil];
  
  if(portNum) {
    args = [args arrayByAddingObjectsFromArray:
            [NSArray arrayWithObjects:
             @"dst-port",
             [NSString stringWithFormat: @"%d", portNum],
             nil
             ]
            ];
  }
  
  NSTask* task = [NSTask launchedTaskWithLaunchPath: kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
}

- (void)addSelfControlBlockRuleAllowingIP:(NSString*)ipAddress port:(int)portNum maskLength:(int)maskLength {
  NSString* blockString = [NSString stringWithString: ipAddress];
  if(maskLength) {
    blockString = [NSString stringWithFormat: @"%@/%d", ipAddress, maskLength];
  }
  
  NSArray* args = [NSArray array];
  args = [NSArray arrayWithObjects:
          @"-q",
          @"add",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
          @"set",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
          @"allow",
          @"ip",
          @"from",
          @"me",
          @"to",
          blockString,
          nil];
  
  if(portNum) {
    args = [args arrayByAddingObjectsFromArray:
            [NSArray arrayWithObjects:
             @"dst-port",
             [NSString stringWithFormat: @"%d", portNum],
             nil
             ]
            ];
  }
  
  NSTask* task = [NSTask launchedTaskWithLaunchPath: kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
}

/* Aliases */

- (void)addSelfControlBlockRuleBlockingIP:(NSString*)ipAddress {    
  [self addSelfControlBlockRuleBlockingIP: ipAddress port: 0 maskLength: 0];
}

- (void)addSelfControlBlockRuleBlockingIP:(NSString*)ipAddress port:(int)portNum {    
  [self addSelfControlBlockRuleBlockingIP: ipAddress port: portNum maskLength: 0];
}

- (void)addSelfControlBlockRuleBlockingIP:(NSString*)ipAddress maskLength:(int)maskLength {
  [self addSelfControlBlockRuleBlockingIP: ipAddress port: 0 maskLength: maskLength];
}

- (void)addSelfControlBlockRuleAllowingIP:(NSString*)ipAddress {    
  [self addSelfControlBlockRuleAllowingIP: ipAddress port: 0 maskLength: 0];
}

- (void)addSelfControlBlockRuleAllowingIP:(NSString*)ipAddress port:(int)portNum {    
  [self addSelfControlBlockRuleAllowingIP: ipAddress port: portNum maskLength: 0];
}

- (void)addSelfControlBlockRuleAllowingIP:(NSString*)ipAddress maskLength:(int)maskLength {    
  [self addSelfControlBlockRuleAllowingIP: ipAddress port: 0 maskLength: maskLength];
}

/* Misc methods */

- (void)addWhitelistFooter {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"allow",
                   @"ip",
                   @"from",
                   @"me",
                   @"to",
                   @"any",
                   @"dst-port",
                   @"53",
                   nil];
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
    
  args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"allow",
                   @"udp",
                   @"from",
                   @"me",
                   @"to",
                   @"any",
                   @"dst-port",
                   @"123",
                   nil];
  task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
    
  args = [NSArray arrayWithObjects:
          @"-q",
          @"add",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
          @"set",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
          @"deny",
          @"ip",
          @"from",
          @"me",
          @"to",
          @"any",
          @"dst-port",
          @"67",
          nil];
  task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
    
  args = [NSArray arrayWithObjects:
          @"-q",
          @"add",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
          @"set",
          [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
          @"deny",
          @"ip",
          @"from",
          @"me",
          @"to",
          @"any",
          @"dst-port",
          @"68",
          nil];
  task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
      
  args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
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
  [allTasks addObject: task];
}

- (void)addSelfControlBlockHeader {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"//",
                   @"BEGIN",
                   @"SELFCONTROL",
                   @"BLOCK",
                   nil];
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
  
  // This adds a rule to allow any traffic coming on the loopback interface, this
  // is necessary because if we accidentally blocked localhost it would make the
  // computer go crazy.
  args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
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
  [allTasks addObject: task];
}

- (void)addSelfControlBlockFooter {
  NSArray* args = [NSArray arrayWithObjects:
                   @"-q",
                   @"add",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleStartNumber + OSAtomicIncrement32(&selfControlBlockRuleCount_)],
                   @"set",
                   [NSString stringWithFormat: @"%d", kIPFirewallRuleSetNumber],
                   @"//",
                   @"END",
                   @"SELFCONTROL",
                   @"BLOCK",
                   nil];                   
  NSTask* task = [NSTask launchedTaskWithLaunchPath:kIPFirewallExecutablePath arguments:args];
  [allTasks addObject: task];
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

- (void)waitUntilAllTasksExit {
  [taskLock lock];
  
  for(int i = 0; i < [allTasks count]; i++) {
    [[allTasks objectAtIndex: i] waitUntilExit];
  }
  
  [allTasks removeAllObjects];
  
  [taskLock unlock];
}

@end