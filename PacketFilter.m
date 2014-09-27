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
		[configText appendString: @"block return out proto tcp from any to any\n"
		 "block return out proto udp from any to any\n"
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
	NSMutableString* rule = [NSMutableString stringWithString: @"from any to "];

	if (ip) {
		[rule appendString: ip];
	} else {
		[rule appendString: @"any"];
	}

	if (maskLen) {
		[rule appendString: [NSString stringWithFormat: @"/%d", maskLen]];
	}

	if (port) {
		[rule appendString: [NSString stringWithFormat: @" port %d", port]];
	}

	@synchronized(self) {
		if (isWhitelist) {
			[rules appendString: [NSString stringWithFormat: @"pass out proto tcp %@\n", rule]];
			[rules appendString: [NSString stringWithFormat: @"pass out proto udp %@\n", rule]];
		} else {
			[rules appendString: [NSString stringWithFormat: @"block return out proto tcp %@\n", rule]];
			[rules appendString: [NSString stringWithFormat: @"block return out proto udp %@\n", rule]];
		}
	}
}

- (void)writeConfiguration {
	NSMutableString* filterConfiguration = [NSMutableString stringWithCapacity: 1000];

	[self addBlockHeader: filterConfiguration];
	[filterConfiguration appendString: rules];

	if (isWhitelist) {
		[self addWhitelistFooter: filterConfiguration];
	}

	[filterConfiguration writeToFile: @"/etc/pf.anchors/org.eyebeam" atomically: true encoding: NSUTF8StringEncoding error: nil];
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
	return [mainConf rangeOfString: @"org.eyebeam"].location != NSNotFound;
}

@end
