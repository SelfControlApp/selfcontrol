//
//  AppDelegate.m
//  SelfControl Killer
//
//  Created by Charles Stigler on 9/21/14.
//
//

#import "AppDelegate.h"
#import "SCSettings.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApplication sharedApplication].delegate = self;

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
		NSLog(@"ERROR: Failed to authorize block kill.");
		return;
	}
    
    // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
    [[SCSettings currentUserSettings] synchronizeSettings];

	char uidString[10];
	snprintf(uidString, sizeof(uidString), "%d", getuid());

	char* args[] = { uidString, NULL };

	status = AuthorizationExecuteWithPrivileges(authorizationRef,
												helperToolPath,
												kAuthorizationFlagDefaults,
												args,
												NULL);
	if(status) {
		NSLog(@"WARNING: Authorized execution of helper tool returned failure status code %d", status);

		NSError* err = [NSError errorWithDomain: @"org.eyebeam.SelfControl-Killer" code: status userInfo: @{NSLocalizedDescriptionKey: @"Error executing privileged helper tool."}];

		[NSApp presentError: err];

		return;
	} else {
		NSAlert* alert = [[NSAlert alloc] init];
		[alert setMessageText: @"Success!"];
		[alert setInformativeText:@"The block was cleared successfully.  You can find the log file, named SelfControl-Killer.log, in your Documents folder."];
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
	if(!path) {
		NSBundle* thisBundle = [NSBundle mainBundle];
		path = [thisBundle pathForAuxiliaryExecutable: @"SCKillerHelper"];
	}

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
