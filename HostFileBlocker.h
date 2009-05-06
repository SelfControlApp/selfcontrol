//
//  HostFileBlocker.h
//  SelfControl
//
//  Created by Charlie Stigler on 4/28/09.
//  Copyright 2009 Harvard-Westlake Student. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HostFileBlocker : NSObject {
  NSMutableString* newFileContents;
}

- (BOOL)writeNewFileContents;

- (void)addSelfControlBlockHeader;

- (void)addSelfControlBlockFooter;

- (void)addRuleBlockingDomain:(NSString*)domainName;

- (BOOL)containsSelfControlBlock;

- (void)removeSelfControlBlock;

@end
