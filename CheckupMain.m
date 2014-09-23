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
	@autoreleasepool {

		if(geteuid()) {
			NSLog(@"ERROR: SUID bit not set on scheckup.");
			printStatus(-201);
			exit(EX_NOPERM);
		}

		NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
		NSDate* blockStartedDate = curDictionary[@"BlockStartedDate"];
		NSTimeInterval blockDuration = [curDictionary[@"BlockDuration"] intValue];


		if(blockStartedDate == nil || [[NSDate distantFuture] isEqualToDate: blockStartedDate] || blockDuration < 1) {
			// The lock file seems to be broken.  Try defaults.
			NSLog(@"WARNING: Lock file unreadable or invalid");
			NSDictionary* defaults = getDefaultsDict(getuid());
			blockStartedDate = defaults[@"BlockStartedDate"];
			blockDuration = [defaults[@"BlockDuration"] intValue];

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
			exit(EXIT_SUCCESS);
		}

	}
	NSLog(@"INFO: scheckup run, but block should still be ongoing.");
	exit(EXIT_SUCCESS);
}

