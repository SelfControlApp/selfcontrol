//
//  HostFileBlocker.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/28/09.
//  Copyright 2009 Harvard-Westlake Student. All rights reserved.
//

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
