//
//  PacketFilter.m
//  SelfControl
//
//  Created by Charles Stigler on 6/29/14.
//
//

#import "PacketFilter.h"

NSString* const kPfctlExecutablePath = @"/sbin/pfctl";

@implementation PacketFilter

- (PacketFilter*)initAsWhitelist: (BOOL)whitelist {
	if (self = [super init]) {
		isWhitelist = whitelist;
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

	if (isWhitelist) {
		[configText appendString: @"deny out proto tcp from any to any\n"
		                           "deny out proto udp from any to any\n"
		                           "\n"];
	}
}
- (void)addWhitelistFooter:(NSMutableString*)configText {
	[configText appendString: @"pass out proto tcp from any to any port 53\n"];
	[configText appendString: @"pass out proto udp from any to any port 53\n"];
	[configText appendString: @"pass out proto udp from any to any port 123\n"];
	[configText appendString: @"pass out proto udp from any to any port 67\n"];
	[configText appendString: @"pass out proto tcp from any to any port 67\n"];
	[configText appendString: @"pass out proto udp from any to any port 68\n"];
	[configText appendString: @"pass out proto tcp from any to any port 68\n"];
}

- (void)addRuleWithIP:(NSString*)ip port:(int)port maskLen:(int)maskLen {
	NSLog(@"add rule with ip %@", ip);
	NSMutableString* rule = [NSMutableString stringWithString: @"from any to "];

	if (ip) {
		[rule appendString: ip];
	} else {
		[rule appendString: @"any"];
	}

	if (maskLen) {
		[rule appendString: [NSString stringWithFormat: @"/%d", maskLen]];
	}

	if (maskLen) {
		[rule appendString: [NSString stringWithFormat: @" port %d", port]];
	}

	if (isWhitelist) {
		[rules appendString: [NSString stringWithFormat: @"pass out proto tcp %@\n", rule]];
		[rules appendString: [NSString stringWithFormat: @"pass out proto udp %@\n", rule]];
	} else {
		[rules appendString: [NSString stringWithFormat: @"block out proto tcp %@\n", rule]];
		[rules appendString: [NSString stringWithFormat: @"block out proto udp %@\n", rule]];
	}
}

- (void)writeConfigurationWithToken:(NSString*)token {
	NSMutableString* filterConfiguration = [NSMutableString stringWithCapacity: 1000];

	if (token) {
		[filterConfiguration appendString: [NSString stringWithFormat: @"# %@\n", token]];
	}

	[self addBlockHeader: filterConfiguration];
	NSLog(@"Rules: %@", rules);
	[filterConfiguration appendString: rules];

	if (isWhitelist) {
		[self addWhitelistFooter: filterConfiguration];
	}

	[filterConfiguration writeToFile: @"/etc/pf.anchors/org.eyebeam" atomically: true encoding: NSUTF8StringEncoding error: nil];
}

- (int)startBlock {
	[self addSelfControlConfig];
	[self writeConfigurationWithToken: nil];

	NSArray* args = [@"-E -f /etc/pf.conf" componentsSeparatedByString: @" "];

	NSTask* task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath: kPfctlExecutablePath];
	[task setArguments: args];

	NSPipe* inPipe = [[[NSPipe alloc] init] autorelease];
	NSFileHandle* readHandle = [inPipe fileHandleForReading];
	[task setStandardOutput: inPipe];

	[task launch];
	NSString* pfctlOutput = [[NSString alloc] initWithData: [readHandle readDataToEndOfFile] encoding: NSUTF8StringEncoding];
	[readHandle closeFile];
	[task waitUntilExit];

	NSArray* lines = [pfctlOutput componentsSeparatedByString: @"\n"];
	for (NSString* line in lines) {
		if ([line hasPrefix: @"Token: "]) {
			[self writeConfigurationWithToken: line];
			break;
		}
	}

	return [task terminationStatus];
}

- (int)stopBlock:(BOOL)force {
	NSString* currentConfig = [NSString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];
	NSString* token;

	NSArray* lines = [currentConfig componentsSeparatedByString: @"\n"];
	for (NSString* line in lines) {
		if ([line hasPrefix: @"# Token :"]) {
			token = [line substringFromIndex: [@"# Token : " length]];
			break;
		}
	}

	[@"" writeToFile: @"/etc/pf.anchors/org.eyebeam" atomically: true encoding: NSUTF8StringEncoding error: nil];

	NSString* mainConf = [NSString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];
	lines = [mainConf componentsSeparatedByString: @"\n"];
	NSMutableString* newConf = [NSMutableString stringWithCapacity: [mainConf length]];
	for (NSString* line in lines) {
		if ([line rangeOfString: @"org.eyebeam"].location == NSNotFound) {
			[newConf appendFormat: @"%@\n", line];
		}
	}
	newConf = [[newConf stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
	[newConf appendString: @"\n"];
	[newConf writeToFile: @"/etc/pf.conf" atomically: true encoding: NSUTF8StringEncoding error: nil];

	NSArray* args;
	if (token && !force) {
		args = [@"-X \(token) -f /etc/pf.conf" componentsSeparatedByString: @" "];
	} else {
		NSLog(@"Couldn't find pf token or using force, disabling with -d");
		args = [@"-d -f /etc/pf.conf" componentsSeparatedByString: @" "];
	}

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
	return [mainConf rangeOfString: @"org.eyebeam"].location != NSNotFound;
}

@end
