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
    fileMan = [[[NSFileManager alloc] init] autorelease];
    strLock = [[NSLock alloc] init];
    newFileContents = [NSMutableString stringWithContentsOfFile: kHostFileBlockerPath usedEncoding: &stringEnc error: NULL];
    if(!newFileContents)
      return nil;
  }
    
  return self;
}

- (void)dealloc {
  [strLock release], strLock = nil;
  [super dealloc];
}

- (BOOL)revertFileContentsToDisk {
  [strLock lock];
  newFileContents = [NSMutableString stringWithContentsOfFile: kHostFileBlockerPath usedEncoding: &stringEnc error: NULL];

  BOOL ret;
  if(newFileContents) ret = YES;
  else ret = NO;

  [strLock unlock];
  return ret;
}

- (BOOL)writeNewFileContents {
  [strLock lock];

  BOOL ret = [newFileContents writeToFile: kHostFileBlockerPath atomically: YES encoding: stringEnc error: NULL];

  [strLock unlock];
  return ret;
}

- (BOOL)createBackupHostsFile {
  NSLog(@"CREATE BACKUP HOSTS FILE!");
  [self deleteBackupHostsFile];
  
  if(![fileMan isReadableFileAtPath: @"/etc/hosts"] || [fileMan fileExistsAtPath: @"/etc/hosts.bak"]) {
    return NO;
  }

  return [fileMan copyItemAtPath: @"/etc/hosts" toPath: @"/etc/hosts.bak" error: nil];
}

- (BOOL)deleteBackupHostsFile {  
  if(![fileMan isDeletableFileAtPath: @"/etc/hosts.bak"])
    return NO;
  
  return [fileMan removeItemAtPath: @"/etc/hosts.bak" error: nil];
}

- (BOOL)restoreBackupHostsFile {    
  if(![fileMan removeItemAtPath: @"/etc/hosts" error: nil])
    return NO;
  if(![fileMan isReadableFileAtPath: @"/etc/hosts.bak"] || ![fileMan moveItemAtPath: @"/etc/hosts.bak" toPath: @"/etc/hosts" error: nil])
    return NO;
  
  return YES;
}

- (void)addSelfControlBlockHeader {
  [strLock lock];
  [newFileContents appendString: @"\n"];
  [newFileContents appendString: kHostFileBlockerSelfControlHeader];
  [newFileContents appendString: @"\n"];
  [strLock unlock];
}

- (void)addSelfControlBlockFooter {
  [strLock lock];
  [newFileContents appendString: kHostFileBlockerSelfControlFooter];
  [newFileContents appendString: @"\n"];
  [strLock unlock];
}

- (void)addRuleBlockingDomain:(NSString*)domainName {
  [strLock lock];
  [newFileContents appendString: [NSString stringWithFormat: @"0.0.0.0\t%@\n", domainName]];
  [newFileContents appendString: [NSString stringWithFormat: @"::\t%@\n", domainName]];
  [strLock unlock];
}

- (BOOL)containsSelfControlBlock {
  [strLock lock];
  
  BOOL ret = ([newFileContents rangeOfString: kHostFileBlockerSelfControlHeader].location != NSNotFound);
  
  [strLock unlock];
  return ret;
}

- (void)removeSelfControlBlock {
  if(![self containsSelfControlBlock])
    return;

  [strLock lock];
  
  NSRange startRange = [newFileContents rangeOfString: kHostFileBlockerSelfControlHeader];
  NSRange endRange = [newFileContents rangeOfString: kHostFileBlockerSelfControlFooter];
  
  NSRange deleteRange = NSMakeRange(startRange.location - 1, ((endRange.location + endRange.length) - startRange.location) + 2);
  
  [newFileContents deleteCharactersInRange: deleteRange];

  [strLock unlock];
}

@end
