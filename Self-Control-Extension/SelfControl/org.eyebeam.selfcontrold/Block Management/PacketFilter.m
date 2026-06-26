//
//  PacketFilter.m
//  SelfControl
//
//  Created by Charles Stigler on 6/29/14.
//
//

#import "PacketFilter.h"

NSString* const kPfctlExecutablePath = @"/sbin/pfctl";
NSString* const kPFConfPath = @"/etc/pf.conf";
NSString* const kPFAnchorCommand = @"anchor \"org.eyebeam\"";

@implementation PacketFilter

NSFileHandle* appendFileHandle;

+ (BOOL)blockFoundInPF {
    // last try if we can't find a block anywhere: check the host file, and see if a block is in there
    NSString* pfConfContents = [NSString stringWithContentsOfFile: kPFConfPath encoding: NSUTF8StringEncoding error: NULL];
    if(pfConfContents != nil && [pfConfContents rangeOfString: kPFAnchorCommand].location != NSNotFound) {
        return YES;
    }

    return NO;
}

- (PacketFilter*)initAsAllowlist: (BOOL)allowlist {
	if (self = [super init]) {
		isAllowlist = allowlist;
		rules = [NSMutableString stringWithCapacity: 1000];
	}
	return self;
}

- (void)addBlockHeader:(NSMutableString*)configText {
	[configText appendString: @"# Options\n"
	 "set block-policy drop\n"
	 "set fingerprints \"/etc/pf.os\"\n"
	 "set ruleset-optimization basic\n"
	 "set skip on lo0\n"
	 "\n"
	 "#\n"
	 "# org.eyebeam ruleset for SelfControl blocks\n"
	 "#\n"];

	if (isAllowlist) {
		[configText appendString: @"block return out proto tcp from any to any\n"
		 "block return out proto udp from any to any\n"
		 "\n"];
	}
}
- (void)addAllowlistFooter:(NSMutableString*)configText {
	[configText appendString: @"pass out proto tcp from any to any port 53\n"];
	[configText appendString: @"pass out proto udp from any to any port 53\n"];
	[configText appendString: @"pass out proto udp from any to any port 123\n"];
	[configText appendString: @"pass out proto udp from any to any port 67\n"];
	[configText appendString: @"pass out proto tcp from any to any port 67\n"];
	[configText appendString: @"pass out proto udp from any to any port 68\n"];
	[configText appendString: @"pass out proto tcp from any to any port 68\n"];
	[configText appendString: @"pass out proto udp from any to any port 5353\n"];
	[configText appendString: @"pass out proto tcp from any to any port 5353\n"];
}

- (NSArray<NSString*>*)ruleStringsForIP:(NSString*)ip port:(NSInteger)port maskLen:(NSInteger)maskLen {
    NSMutableString* rule = [NSMutableString stringWithString: @"from any to "];

    if (ip) {
        [rule appendString: ip];
    } else {
        [rule appendString: @"any"];
    }

    if (maskLen) {
        [rule appendString: [NSString stringWithFormat: @"/%ld", (long)maskLen]];
    }

    if (port) {
        [rule appendString: [NSString stringWithFormat: @" port %ld", (long)port]];
    }

    if (isAllowlist) {
        return @[
            [NSString stringWithFormat: @"pass out proto tcp %@\n", rule],
            [NSString stringWithFormat: @"pass out proto udp %@\n", rule]
        ];
    } else {
        return @[
            [NSString stringWithFormat: @"block return out proto tcp %@\n", rule],
            [NSString stringWithFormat: @"block return out proto udp %@\n", rule]
        ];
    }
}
- (void)addRuleWithIP:(NSString*)ip port:(NSInteger)port maskLen:(NSInteger)maskLen {
    @synchronized(self) {
        NSArray<NSString*>* ruleStrings = [self ruleStringsForIP: ip port: port maskLen: maskLen];
        for (NSString* ruleString in ruleStrings) {
            if (appendFileHandle) {
                [appendFileHandle writeData: [ruleString dataUsingEncoding:NSUTF8StringEncoding]];
            } else {
                [rules appendString: ruleString];
            }
        }
    }
}

- (void)writeConfiguration {
	NSMutableString* filterConfiguration = [NSMutableString stringWithCapacity: 1000];

	[self addBlockHeader: filterConfiguration];
	[filterConfiguration appendString: rules];

	if (isAllowlist) {
		[self addAllowlistFooter: filterConfiguration];
	}

	[filterConfiguration writeToFile: @"/etc/pf.anchors/org.eyebeam" atomically: true encoding: NSUTF8StringEncoding error: nil];
}

- (void)enterAppendMode {
    if (isAllowlist) {
        NSLog(@"WARNING: Can't append rules to allowlist blocks - ignoring");
        return;
    }

    // open the file and prepare to write to the very bottom (no footer since it's not an allowlist)
    appendFileHandle = [NSFileHandle fileHandleForWritingAtPath: @"/etc/pf.anchors/org.eyebeam"];
    if (!appendFileHandle) {
        NSLog(@"ERROR: Failed to get handle for pf.anchors file while attempting to append rules");
        return;
    }

    [appendFileHandle seekToEndOfFile];
}
- (void)finishAppending {
    [appendFileHandle closeFile];
    appendFileHandle = nil;
}

- (void)appendRulesToCurrentBlockConfiguration:(NSArray<NSDictionary*>*)newEntryDicts {
    if (newEntryDicts.count < 1) return;
    if (isAllowlist) {
        NSLog(@"WARNING: Can't append rules to allowlist blocks - ignoring");
        return;
    }

    // open the file and prepare to write to the very bottom (no footer since it's not an allowlist)
    // NOTE FOR FUTURE: NSFileHandle can't append lines to the middle of the file anyway,
    // would need to read in the whole thing + write out again
    NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath: @"/etc/pf.anchors/org.eyebeam"];
    if (!fileHandle) {
        NSLog(@"ERROR: Failed to get handle for pf.anchors file while attempting to append rules");
        return;
    }

    [fileHandle seekToEndOfFile];
    for (NSDictionary* entryHostInfo in newEntryDicts) {
        NSString* hostName = entryHostInfo[@"hostName"];
        int portNum = [entryHostInfo[@"port"] intValue];
        int maskLen = [entryHostInfo[@"maskLen"] intValue];

        NSArray<NSString*>* ruleStrings = [self ruleStringsForIP: hostName port: portNum maskLen: maskLen];
        for (NSString* ruleString in ruleStrings) {
            [fileHandle writeData: [ruleString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    [fileHandle closeFile];
}

- (int)startBlock {
	[self addSelfControlConfig];
	[self writeConfiguration];

	NSArray* args = [@"-E -f /etc/pf.conf -F states" componentsSeparatedByString: @" "];

	NSTask* task = [[NSTask alloc] init];
	[task setLaunchPath: kPfctlExecutablePath];
	[task setArguments: args];

	NSPipe* inPipe = [[NSPipe alloc] init];
	NSFileHandle* readHandle = [inPipe fileHandleForReading];
	[task setStandardOutput: inPipe];
	[task setStandardError: inPipe];

	[task launch];
	NSString* pfctlOutput = [[NSString alloc] initWithData: [readHandle readDataToEndOfFile] encoding: NSUTF8StringEncoding];
	[readHandle closeFile];
	[task waitUntilExit];

	NSArray* lines = [pfctlOutput componentsSeparatedByString: @"\n"];
	for (NSString* line in lines) {
		if ([line hasPrefix: @"Token : "]) {
			[self writePFToken: [line substringFromIndex: [@"Token : " length]] error: nil];
			break;
		}
	}

	return [task terminationStatus];
}
- (int)refreshPFRules {
    NSArray* args = [@"-f /etc/pf.conf -F states" componentsSeparatedByString: @" "];

    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath: kPfctlExecutablePath];
    [task setArguments: args];
    [task launch];
    [task waitUntilExit];

    return [task terminationStatus];
}

- (void)writePFToken:(NSString*)token error:(NSError**)error {
	[token writeToFile: @"/etc/SelfControlPFToken" atomically: YES encoding: NSUTF8StringEncoding error: error];
}
- (NSString*)readPFToken:(NSError**)error {
	return [NSString stringWithContentsOfFile: @"/etc/SelfControlPFToken" encoding: NSUTF8StringEncoding error: error];
}

- (int)stopBlock:(BOOL)force {
	NSError* err;
	NSString* token = [self readPFToken: &err];

	[@"" writeToFile: @"/etc/pf.anchors/org.eyebeam" atomically: true encoding: NSUTF8StringEncoding error: nil];
	NSString* mainConf = [NSString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];
	NSArray* lines = [mainConf componentsSeparatedByString: @"\n"];
	NSMutableString* newConf = [NSMutableString stringWithCapacity: [mainConf length]];
	for (NSString* line in lines) {
		if ([line rangeOfString: @"org.eyebeam"].location == NSNotFound) {
			[newConf appendFormat: @"%@\n", line];
		}
	}
	newConf = [[newConf stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
	[newConf appendString: @"\n"];
	[newConf writeToFile: @"/etc/pf.conf" atomically: true encoding: NSUTF8StringEncoding error: nil];

	NSString* commandString;
	if ([token length] && !force) {
		commandString = [NSString stringWithFormat: @"-X %@ -f /etc/pf.conf", token];
	} else {
		commandString = @"-d -f /etc/pf.conf";
	}
	NSArray* args = [commandString componentsSeparatedByString: @" "];

	NSTask* task = [NSTask launchedTaskWithLaunchPath: kPfctlExecutablePath arguments: args];
	[task waitUntilExit];
	return [task terminationStatus];
}

- (void)addSelfControlConfig {
	NSMutableString* pfConf = [NSMutableString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];

	if ([pfConf rangeOfString: @"/etc/pf.anchors/org.eyebeam"].location == NSNotFound) {
		[pfConf appendString: @"\n"
		 "anchor \"org.eyebeam\"\n"
		 "load anchor \"org.eyebeam\" from \"/etc/pf.anchors/org.eyebeam\"\n"];
	}

	[pfConf writeToFile: @"/etc/pf.conf" atomically: true encoding: NSUTF8StringEncoding error: nil];
}

- (BOOL)containsSelfControlBlock {
	NSString* mainConf = [NSString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];
	return mainConf != nil && [mainConf rangeOfString: @"org.eyebeam"].location != NSNotFound;
}

@end
