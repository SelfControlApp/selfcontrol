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

        SCSettings* settings = [SCSettings settingsForUser: getuid()];
        
        if(![SCBlockDateUtilities blockIsEnabledInDictionary: settings.settingsDictionary]) {
            // something's, wrong, we shouldn't be run if there's no block
            // so just try to remove one anyway, just in case
            NSLog(@"WARNING: Checkup ran but no block found.  Attempting to remove block.");

            // get rid of this block
            removeBlock(getuid());

            exit(EXIT_SUCCESS);
        }

		if(![SCBlockDateUtilities blockIsActiveInDictionary: settings.settingsDictionary]) {
			NSLog(@"INFO: Checkup helper ran, block expired, removing block.");
            
			removeBlock(getuid());
			exit(EXIT_SUCCESS);
		}

	}
	NSLog(@"INFO: scheckup run, but block should still be ongoing.");
	exit(EXIT_SUCCESS);
}

