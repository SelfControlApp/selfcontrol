/*
 *  CheckupMain.c
 *  SelfControl
 *
 *  Created by Charlie Stigler on 7/13/10.
 *  Copyright 2010 Harvard-Westlake Student. All rights reserved.
 *
 */

#include "CheckupMain.h"
#import "SCBlockDateUtilities.h"
#import "SCSettings.h"

int main(int argc, char* argv[]) {
	@autoreleasepool {

		if(geteuid()) {
			NSLog(@"ERROR: SUID bit not set on scheckup.");
			printStatus(-201);
			exit(EX_NOPERM);
		}

		NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLegacyLockFilePath];

		if(![SCBlockDateUtilities blockIsEnabledInDictionary: curDictionary]) {
			// The lock file seems to be broken.  Try settings.
			NSLog(@"WARNING: Lock file unreadable or invalid");
            curDictionary = [SCSettings settingsForUser: getuid()];

			if(![SCBlockDateUtilities blockIsEnabledInDictionary: curDictionary]) {
				// Settings are broken too!  Let's get out of here!
				NSLog(@"WARNING: Checkup ran but no block found.  Attempting to remove block.");

				// get rid of this block
				removeBlock(getuid());

				exit(EXIT_SUCCESS);
			}
		}

		if(![SCBlockDateUtilities blockIsActiveInDictionary: curDictionary]) {
			NSLog(@"INFO: Checkup helper ran, block expired, removing block.");
			removeBlock(getuid());
			exit(EXIT_SUCCESS);
		}

	}
	NSLog(@"INFO: scheckup run, but block should still be ongoing.");
	exit(EXIT_SUCCESS);
}

