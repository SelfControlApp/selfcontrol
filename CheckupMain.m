/*
 *  CheckupMain.c
 *  SelfControl
 *
 *  Created by Charlie Stigler on 7/13/10.
 *  Copyright 2010 Harvard-Westlake Student. All rights reserved.
 *
 */

#include "CheckupMain.h"

int main(int argc, char* argv[]) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
      
  if(geteuid()) {
    NSLog(@"ERROR: SUID bit not set on scheckup.");
    printStatus(-201); 
    exit(EX_NOPERM);
  }
          
  NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
  NSDate* blockStartedDate = [curDictionary objectForKey: @"BlockStartedDate"];
  NSTimeInterval blockDuration = [[curDictionary objectForKey: @"BlockDuration"] intValue];
      
  
  if(blockStartedDate == nil || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || blockDuration < 1) {    
    // The lock file seems to be broken.  Try defaults.
    NSLog(@"WARNING: Lock file unreadable or invalid");
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(getuid());
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed:@"org.eyebeam.SelfControl"];
    blockStartedDate = [defaults objectForKey: @"BlockStartedDate"];
    blockDuration = [[defaults objectForKey: @"BlockDuration"] intValue];
    [defaults synchronize];
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    if(blockStartedDate == nil || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || blockDuration < 1) {    
      // Defaults is broken too!  Let's get out of here!
      NSLog(@"WARNING: Checkup ran but no block found.  Attempting to remove block.");
      
      // get rid of this block
      removeBlock(getuid());
      
      printStatus(-215);
      exit(EX_SOFTWARE);
    }
  }
    
  // convert to seconds
  blockDuration *= 60;
  
  NSTimeInterval timeSinceStarted = [[NSDate date] timeIntervalSinceDate: blockStartedDate];
    
  if( blockStartedDate == nil || blockDuration < 1 || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || timeSinceStarted >= blockDuration) {
    NSLog(@"INFO: Checkup helper ran, block expired, removing block.");            
        
    removeBlock(getuid());
  }  
    
  [pool drain];
  NSLog(@"INFO: scheckup run, but block should still be ongoing.");
  exit(EXIT_SUCCESS);
}

