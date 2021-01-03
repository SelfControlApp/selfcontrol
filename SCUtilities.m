//
//  SCBlockDateUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import "SCUtilities.h"
#import "HelperCommon.h"
#import "SCSettings.h"

@implementation SCUtilities

// Standardize and clean up the input value so it'll block properly (and look good doing it)
// note that if the user entered line breaks, we'll split it into many entries, so this can return multiple
// cleaned entries in the NSArray it returns
+ (NSArray<NSString*>*) cleanBlocklistEntry:(NSString*)rawEntry {
    if (rawEntry == nil) return @[];
    
	// This'll remove whitespace and lowercase the string.
	NSString* str = [[rawEntry stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

    // if there are newlines in the string, split it and process it as many strings
	if([str rangeOfCharacterFromSet: [NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
		NSArray* splitEntries = [str componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
        
        NSMutableArray* returnArr = [NSMutableArray new];
        for (NSString* splitEntry in splitEntries) {
            // recursion makes the rest of the code prettier
            NSArray<NSString*>* cleanedSubEntries = [SCUtilities cleanBlocklistEntry: splitEntry];
            [returnArr addObjectsFromArray: cleanedSubEntries];
        }
        return returnArr;
    }
    
    // if the user entered a scheme (https://, http://, etc) remove it.
    // We only block hostnames so scheme is ignored anyway and it can gunk up the blocking
    NSArray* separatedStr = [str componentsSeparatedByString: @"://"];
    str = [separatedStr lastObject];
    
	// Remove URL login names/passwords (username:password@host) if a user tried to put that in
	separatedStr = [str componentsSeparatedByString: @"@"];
	str = [separatedStr lastObject];
    
    // now here's where it gets tricky. Besides just hostnames, we also support CIDR IP ranges, for example: 83.0.1.2/24
    // so we are gonna keep track of whether we might have received a valid CIDR IP range instead of hostname as we go...
    // we also take port numbers, so keep track of whether we have one of those
	int cidrMaskBits = -1;
	int portNum = -1;

    // first pull off everything after a slash
    // discard the end if it's just a path, but check to see if it might be our CIDR mask length
	separatedStr = [str componentsSeparatedByString: @"/"];
    str = [separatedStr firstObject];
    
    // if the part after a slash is an integer between 1 and 128, it could be our mask length
    if (separatedStr.count > 1) {
        int potentialMaskLen = [[separatedStr lastObject] intValue];
        if (potentialMaskLen > 0 && potentialMaskLen <= 128) cidrMaskBits = potentialMaskLen;
    }

    // check for the port
    separatedStr = [str componentsSeparatedByString: @":"];
    str = [separatedStr firstObject];
    
    if (separatedStr.count > 1) {
        int potentialPort = [[separatedStr lastObject] intValue];
        if (potentialPort > 0 && potentialPort <= 65535) {
            portNum = potentialPort;
        }
    }
    
    // remove invalid characters from the hostname
    // hostnames are 1-253 characters long, and can contain only a-z, A-Z, 0-9, -, and ., and maybe _ (mostly not but kinda)
    // for some reason [NSCharacterSet URLHostAllowedCharacterSet] has tons of other characters that aren't actually valid
    NSMutableCharacterSet* invalidHostnameChars = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [invalidHostnameChars addCharactersInString: @"-._"];
    [invalidHostnameChars invert];

    NSMutableString* validCharsOnly = [NSMutableString stringWithCapacity: str.length];
    for (NSUInteger i = 0; i < str.length && i < 253; i++) {
        unichar c = [str characterAtIndex: i];
        if (![invalidHostnameChars characterIsMember: c]) {
            [validCharsOnly appendFormat: @"%C", c];
        }
    }
    str = validCharsOnly;
    
    // allow blocking an empty hostname IFF we're only blocking a single port number (i.e. :80)
    // otherwise, empty hostname = nothing to do
    if (str.length < 1 && portNum < 0) {
        return @[];
    }

    NSString* maskString;
    NSString* portString;

    // create a mask string if we have one
    if (cidrMaskBits < 0) {
        maskString = @"";
    } else {
        maskString = [NSString stringWithFormat: @"/%d", cidrMaskBits];
    }
    
    // create a port string if we have one
    if (portNum < 0) {
        portString = @"";
    } else {
        portString = [NSString stringWithFormat: @":%d", portNum];
    }

    // combine em together and you got something!
    return @[[NSString stringWithFormat: @"%@%@%@", str, maskString, portString]];
}


+ (BOOL) blockIsRunningWithSettings:(SCSettings*)settings defaults:(NSUserDefaults*)defaults {
    // first we look for the answer in the SCSettings system
    if ([SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]) {
        return YES;
    }

    // next we check the host file, and see if a block is in there
    NSString* hostFileContents = [NSString stringWithContentsOfFile: @"/etc/hosts" encoding: NSUTF8StringEncoding error: NULL];
    if(hostFileContents != nil && [hostFileContents rangeOfString: @"# BEGIN SELFCONTROL BLOCK"].location != NSNotFound) {
        return YES;
    }

    // finally, we should check the legacy ways of storing a block (defaults and lockfile)

    [defaults synchronize];
    if ([SCUtilities blockIsRunningInDictionary: defaults.dictionaryRepresentation]) {
        return YES;
    }

    // If there's no block in the hosts file, SCSettings block in the defaults, and no lock-file,
    // we'll assume we're clear of blocks.  Checking pf would be nice but usually requires
    // root permissions, so it would be difficult to do here.
    return [[NSFileManager defaultManager] fileExistsAtPath: SelfControlLegacyLockFilePath];
}

// returns YES if a block is actively running (to the best of our knowledge), and NO otherwise
+ (BOOL) blockIsRunningInDictionary:(NSDictionary *)dict {
    // simple: the block is running if BlockIsRunning is set to true!
    return [[dict valueForKey: @"BlockIsRunning"] boolValue];
}

// returns YES if the block should be active based on the specified end time (i.e. it is in the future), or NO otherwise
+ (BOOL) blockShouldBeRunningInDictionary:(NSDictionary *)dict {
    // the block should be running if the end date hasn't arrived yet
    if ([[dict objectForKey: @"BlockEndDate"] timeIntervalSinceNow] > 0) {
        return YES;
    } else {
        return NO;
    }
}

+ (void) startBlockInSettings:(SCSettings*)settings withBlockDuration:(NSTimeInterval)blockDuration {
    // sanity check duration (must be above zero)
    blockDuration = MAX(blockDuration, 0);
    
    // assume the block is starting now
    NSDate* blockEndDate = [NSDate dateWithTimeIntervalSinceNow: blockDuration];
    
    [settings setValue: blockEndDate forKey: @"BlockEndDate"];
}


+ (void) removeBlockFromSettings:(SCSettings*)settings {
    // TODO: will this work setting nil instead of [NSDate dateWithTimeIntervalSince1970: 0]?
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue: nil forKey: @"BlockIsRunning"];
    [settings setValue: nil forKey: @"ActiveBlocklist"];
    [settings setValue: nil forKey: @"ActiveBlockAsWhitelist"];
}

+ (void) removeBlockFromSettingsForUID:(uid_t)uid {
    SCSettings* settings = [SCSettings settingsForUser: uid];
    [SCUtilities removeBlockFromSettings: settings];
}

+ (BOOL)blockIsRunningInLegacyDictionary:(NSDictionary*)dict {
    NSDate* blockStartedDate = [dict objectForKey:@"BlockStartedDate"];

    // the block is running if BlockStartedDate exists and isn't equal to the default value
    if (blockStartedDate != nil && ![blockStartedDate isEqualToDate: [NSDate distantFuture]]) {
        return YES;
    } else {
        return NO;
    }
}
+ (NSDate*) endDateFromLegacyBlockDictionary:(NSDictionary *)dict {
    NSDate* startDate = [dict objectForKey: @"BlockStartedDate"];
    NSTimeInterval duration = [[dict objectForKey: @"BlockDuration"] floatValue];
    
    // if we don't have a start date in the past and a duration greater than 0, we don't have a block end date
    if (startDate == nil || [startDate timeIntervalSinceNow] >= 0 || duration <= 0) {
        return [NSDate distantPast];
    }
    
    // convert the legacy start date to an end date
    return [startDate dateByAddingTimeInterval: (duration * 60)];
}

+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo errorDescription:(NSString**)errDescriptionRef {
    NSDictionary* saveDict = @{@"HostBlacklist": [blockInfo objectForKey: @"Blocklist"],
                               @"BlockAsWhitelist": [blockInfo objectForKey: @"BlockAsWhitelist"]};

    NSString* saveDataErr;
    NSData* saveData = [NSPropertyListSerialization dataFromPropertyList: saveDict format: NSPropertyListBinaryFormat_v1_0 errorDescription: &saveDataErr];
    if (saveDataErr != nil) {
        *errDescriptionRef = saveDataErr;
        return NO;
    }

    if (![saveData writeToURL: targetFileURL atomically: YES]) {
        NSLog(@"ERROR: Failed to write blocklist to URL %@", targetFileURL);
        return NO;
    }
    
    // for prettiness sake, attempt to hide the file extension
    NSDictionary* attribs = @{NSFileExtensionHidden: @YES};
    [[NSFileManager defaultManager] setAttributes: attribs ofItemAtPath: [targetFileURL path] error: NULL];
    
    return YES;
}

+ (NSDictionary*)readBlocklistFromFile:(NSURL*)fileURL {
    NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfURL: fileURL];
    
    if (openedDict == nil || openedDict[@"HostBlacklist"] == nil || openedDict[@"BlockAsWhitelist"] == nil) {
        NSLog(@"ERROR: Could not read a valid block from file %@", fileURL);
        return nil;
    }
    
    return @{
        @"Blocklist": openedDict[@"HostBlacklist"],
        @"BlockAsWhitelist": openedDict[@"BlockAsWhitelist"]
    };
}

@end
