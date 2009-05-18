//
//  HostFileBlocker.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/28/09.
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

#import "HostFileBlocker.h"

NSString* const kHostFileBlockerPath = @"/etc/hosts";
NSString* const kHostFileBlockerSelfControlHeader = @"# BEGIN SELFCONTROL BLOCK";
NSString* const kHostFileBlockerSelfControlFooter = @"# END SELFCONTROL BLOCK";

@implementation HostFileBlocker

- (HostFileBlocker*)init {
  if(self = [super init]) {
    newFileContents = [NSMutableString stringWithContentsOfFile: kHostFileBlockerPath encoding: NSUTF8StringEncoding error: NULL];
    if(!newFileContents)
      return nil;
  }
    
  return self;
}    

- (BOOL)writeNewFileContents {
  return [newFileContents writeToFile: kHostFileBlockerPath atomically: YES encoding: NSUTF8StringEncoding error: NULL];
}

- (void)addSelfControlBlockHeader {
  [newFileContents appendString: @"\n"];
  [newFileContents appendString: kHostFileBlockerSelfControlHeader];
  [newFileContents appendString: @"\n"];
}

- (void)addSelfControlBlockFooter {
  [newFileContents appendString: kHostFileBlockerSelfControlFooter];
  [newFileContents appendString: @"\n"];
}

- (void)addRuleBlockingDomain:(NSString*)domainName {
  [newFileContents appendString: [NSString stringWithFormat: @"127.0.0.1\t%@\n", domainName]];
}

- (BOOL)containsSelfControlBlock {
  return ([newFileContents rangeOfString: kHostFileBlockerSelfControlHeader].location != NSNotFound);
}

- (void)removeSelfControlBlock {
  if(![self containsSelfControlBlock])
    return;
  
  NSRange startRange = [newFileContents rangeOfString: kHostFileBlockerSelfControlHeader];
  NSRange endRange = [newFileContents rangeOfString: kHostFileBlockerSelfControlFooter];
  
  NSRange deleteRange = NSMakeRange(startRange.location - 1, ((endRange.location + endRange.length) - startRange.location) + 2);
  
  [newFileContents deleteCharactersInRange: deleteRange];
}

@end
