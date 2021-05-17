//
//  AppDelegate.m
//  SelfControl Killer
//
//  Created by Charles Stigler on 9/21/14.
//
//

#import "AppDelegate.h"
#import "SCSettings.h"
#import "SCMiscUtilities.h"
#import "SCUIUtilities.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApplication sharedApplication].delegate = self;

    [SCSentry startSentry: @"com.selfcontrolapp.SelfControl-Killer"];
    
	[self updateUserInterface];
}

- (IBAction)killButtonClicked:(id)sender {
	AuthorizationRef authorizationRef;
	char* helperToolPath = [self selfControlKillerHelperToolPathUTF8String];
	NSUInteger helperToolPathSize = strlen(helperToolPath);
	AuthorizationItem right = {
		kAuthorizationRightExecute,
		helperToolPathSize,
		helperToolPath,
		0
	};
	AuthorizationRights authRights = {
		1,
		&right
	};
	AuthorizationFlags myFlags = kAuthorizationFlagDefaults |
	kAuthorizationFlagExtendRights |
	kAuthorizationFlagInteractionAllowed;
	OSStatus status;

	status = AuthorizationCreate (&authRights,
								  kAuthorizationEmptyEnvironment,
								  myFlags,
								  &authorizationRef);

	if(status) {
        // if it's just the user cancelling, make that obvious
        // to any listeners so they can ignore it appropriately
        if (status != AUTH_CANCELLED_STATUS) {
            NSLog(@"ERROR: Failed to authorize block kill with status %d.", status);
        }
        return;
	}
    
    // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
    [[SCSettings sharedSettings] synchronizeSettings];

	char uidString[10];
	snprintf(uidString, sizeof(uidString), "%d", getuid());
    
    NSDate* keyDate = [NSDate date];
    NSString* killerKey = [SCMiscUtilities killerKeyForDate: keyDate];
    NSString* keyDateString = [[NSISO8601DateFormatter new] stringFromDate: keyDate];
    
    char* args[] = { (char*)[killerKey UTF8String], (char*)[keyDateString UTF8String], uidString, NULL };

    FILE* pipe = NULL;
	status = AuthorizationExecuteWithPrivileges(authorizationRef,
												helperToolPath,
												kAuthorizationFlagDefaults,
												args,
												&pipe);
	if(status) {
		NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", status);

        /// AUTH_CANCELLED_STATUS just means auth is cancelled, not really an "error" per se
        if (status != AUTH_CANCELLED_STATUS) {
            NSError* err = [SCErr errorWithCode: 400];
            [SCSentry captureError: err];
            [SCUIUtilities presentError: err];
        }

		return;
	}
    
    // read until the pipe finishes so we wait for execution to end before we
    // show the modal (so we can check if the block is cleared properly or not)
    for (;;) {
        ssize_t bytesRead = read(fileno(pipe), NULL, 256);
        if (bytesRead < 1) break;
    }
        
    // reload settings since they've probably just been messed with
    [[SCSettings sharedSettings] reloadSettings];

    // send some debug info to Sentry to help us track this issue
    [SCSentry captureMessage: @"User manually cleared SelfControl block from the SelfControl Killer app"];
    
    if ([SCBlockUtilities anyBlockIsRunning]) {
        // ruh roh! the block wasn't cleared successfully, since it's still running
        NSError* err = [SCErr errorWithCode: 401];
        [SCSentry captureError: err];
        [SCUIUtilities presentError: err];
    } else {
        NSAlert* alert = [[NSAlert alloc] init];
        [alert setMessageText: @"Success!"];
        [alert setInformativeText:@"The block was cleared successfully.  You can find the log file, named SelfControl-Killer.log, in your Documents folder. If you're still having issues, please check out the SelfControl FAQ on GitHub."];
        [alert addButtonWithTitle: @"OK"];
        [alert runModal];
    }

	[self.viewButton setEnabled: YES];
}

- (void)updateUserInterface {
	if([[NSFileManager defaultManager] fileExistsAtPath: [@"~/Documents/SelfControl-Killer.log" stringByExpandingTildeInPath]]) {
		[self.viewButton setEnabled: YES];
	}
}

- (NSString*)selfControlKillerHelperToolPath {
	static NSString* path;

	// Cache the path so it doesn't have to be searched for again.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		NSBundle* thisBundle = [NSBundle mainBundle];
		path = [thisBundle pathForAuxiliaryExecutable: @"SCKillerHelper"];
    });

	return path;
}
- (char*)selfControlKillerHelperToolPathUTF8String {
	static char* path;

	// Cache the converted path so it doesn't have to be converted again
	if(!path) {
		path = malloc(512);
		[[self selfControlKillerHelperToolPath] getCString: path
												 maxLength: 512
												  encoding: NSUTF8StringEncoding];
	}

	return path;
}

- (IBAction)viewButtonClicked:(id)sender {
	if([[NSFileManager defaultManager] fileExistsAtPath: [@"~/Documents/SelfControl-Killer.log" stringByExpandingTildeInPath]])
		[[NSWorkspace sharedWorkspace] openFile: [@"~/Documents/SelfControl-Killer.log" stringByExpandingTildeInPath]];
}

@end
