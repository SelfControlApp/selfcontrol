//
//  SCMiscUtilities.m
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import "SCHelperToolUtilities.h"
#import "SCSettings.h"
#import <CommonCrypto/CommonCrypto.h>
#include <IOKit/IOKitLib.h>

@implementation SCMiscUtilities

// copied from stevenojo's GitHub snippet: https://gist.github.com/stevenojo/e1dcc2b3e2fd4ed1f411eef88e254cb0
+ (dispatch_source_t)createDebounceDispatchTimer:(double)debounceTime queue:(dispatch_queue_t)queue block:(dispatch_block_t)block {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, debounceTime * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    
    return timer;
}

// by Martin R et al on StackOverflow: https://stackoverflow.com/a/15451318
+ (NSString *)getSerialNumber {
    NSString *serial = nil;
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    if (platformExpert) {
        CFTypeRef serialNumberAsCFString =
        IORegistryEntryCreateCFProperty(platformExpert,
                                        CFSTR(kIOPlatformSerialNumberKey),
                                        kCFAllocatorDefault, 0);
        if (serialNumberAsCFString) {
            serial = CFBridgingRelease(serialNumberAsCFString);
        }
        
        IOObjectRelease(platformExpert);
    }
    return serial;
}
// by hypercrypt et al on StackOverflow: https://stackoverflow.com/a/7571583
+ (NSString *)sha1:(NSString*)stringToHash
{
    NSData *data = [stringToHash dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}

+ (BOOL)systemThirdPartyCrashReportingEnabled {
    NSUserDefaults* appleCrashReporter = [NSUserDefaults standardUserDefaults];
    [appleCrashReporter addSuiteNamed: @"/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist"];

    return [appleCrashReporter boolForKey: @"ThirdPartyDataSubmit"];
}

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
            NSArray<NSString*>* cleanedSubEntries = [SCMiscUtilities cleanBlocklistEntry: splitEntry];
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

+ (NSArray<NSString*>*)cleanBlocklist:(NSArray<NSString*>*)blocklist {
    NSMutableArray<NSString*>* cleanedList = [NSMutableArray arrayWithCapacity: blocklist.count];

    // for now, we just remove whitespace and then remove empty entries
    // in the future, this method could do more thorough cleaning
    for (NSString* blockString in blocklist) {
        NSString* cleanedString = [blockString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (cleanedString.length > 0) {
            [cleanedList addObject: cleanedString];
        }
    }

    return cleanedList;
}

+ (NSDictionary*) defaultsDictForUser:(uid_t) controllingUID {
    if (geteuid() != 0) {
        // if we're not root, we can't just get defaults for some arbitrary user
        return nil;
    }
    
    // pull up the user's defaults in the old legacy way
    // to do that, we have to seteuid to the controlling UID so NSUserDefaults thinks we're them
    seteuid(controllingUID);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
    [defaults registerDefaults: SCConstants.defaultUserDefaults];
    [defaults synchronize];
    NSDictionary* dictValue = [defaults dictionaryRepresentation];
    // reset the euid so nothing else gets funky
    [NSUserDefaults resetStandardUserDefaults];
    seteuid(0);
    
    return dictValue;
}

+ (BOOL)errorIsAuthCanceled:(NSError*)err {
    if (err == nil) return NO;
    
    if ([err.domain isEqualToString: NSOSStatusErrorDomain] && err.code == AUTH_CANCELLED_STATUS) {
        return YES;
    }
    if ([err.domain isEqualToString: kSelfControlErrorDomain] && err.code == 1) {
        return YES;
    }
    
    return NO;
}

+ (NSArray<NSURL*>*)allUserHomeDirectoryURLs:(NSError**)errPtr {
    NSError* retErr = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL* usersFolderURL = [NSURL fileURLWithPath: @"/Users"];
    NSArray<NSURL *>* homeDirectoryURLs = [fileManager contentsOfDirectoryAtURL: usersFolderURL
                                                     includingPropertiesForKeys: @[NSURLPathKey, NSURLIsDirectoryKey, NSURLIsReadableKey]
                                                                        options: NSDirectoryEnumerationSkipsHiddenFiles
                                                                          error: &retErr];
    if (homeDirectoryURLs == nil || homeDirectoryURLs.count == 0) {
        if (retErr != nil) {
            *errPtr = retErr;
        } else {
            *errPtr = [SCErr errorWithCode: 700];
        }
        
        [SCSentry captureError: *errPtr];
        
        return nil;
    }
    
    return homeDirectoryURLs;
}

+ (NSString*)killerKeyForDate:(NSDate*)date {
    return [SCMiscUtilities sha1: [NSString stringWithFormat: @"SelfControlKillerKey%@%@", [SCMiscUtilities getSerialNumber], [date descriptionWithLocale: nil]]];
}

@end
