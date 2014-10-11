//
//  BlockManager.m
//  SelfControl
//
//  Created by Charles Stigler on 2/5/13.
//  Copyright 2009 Eyebeam.

// This file is part of SelfControl.
//
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "BlockManager.h"
#import "WhitelistScraper.h"

@implementation BlockManager

- (BlockManager*)init {
	return [self initAsWhitelist: NO allowLocal: YES includeCommonSubdomains: YES];
}

- (BlockManager*)initAsWhitelist:(BOOL)whitelist {
	return [self initAsWhitelist: whitelist allowLocal: YES includeCommonSubdomains: YES];
}

- (BlockManager*)initAsWhitelist:(BOOL)whitelist allowLocal:(BOOL)local {
	return [self initAsWhitelist: whitelist allowLocal: local includeCommonSubdomains: YES];
}
- (BlockManager*)initAsWhitelist:(BOOL)whitelist allowLocal:(BOOL)local includeCommonSubdomains:(BOOL)blockCommon {
	return [self initAsWhitelist: whitelist allowLocal: local includeCommonSubdomains: blockCommon includeLinkedDomains: YES];
}

- (BlockManager*)initAsWhitelist:(BOOL)whitelist allowLocal:(BOOL)local includeCommonSubdomains:(BOOL)blockCommon includeLinkedDomains:(BOOL)includeLinked {
	if(self = [super init]) {
		opQueue = [[NSOperationQueue alloc] init];
		[opQueue setMaxConcurrentOperationCount: 20];

		pf = [[PacketFilter alloc] initAsWhitelist: whitelist];
		hostsBlocker = [[HostFileBlocker alloc] init];
		hostsBlockingEnabled = NO;

		isWhitelist = whitelist;
		allowLocal = local;
		includeCommonSubdomains = blockCommon;
		includeLinkedDomains = includeLinked;
	}

	return self;
}

- (void)prepareToAddBlock {
	if([hostsBlocker containsSelfControlBlock]) {
		[hostsBlocker removeSelfControlBlock];
		[hostsBlocker writeNewFileContents];
	}

	if(!isWhitelist && ![hostsBlocker containsSelfControlBlock] && [hostsBlocker createBackupHostsFile]) {
		[hostsBlocker addSelfControlBlockHeader];
		hostsBlockingEnabled = YES;
	} else {
		hostsBlockingEnabled = NO;
	}
}

- (void)finalizeBlock {
	[opQueue waitUntilAllOperationsAreFinished];

	if(hostsBlockingEnabled) {
		[hostsBlocker addSelfControlBlockFooter];
		[hostsBlocker writeNewFileContents];
	}

	[pf startBlock];
}

- (void)enqueueBlockEntryWithHostName:(NSString*)hostName port:(int)portNum maskLen:(int)maskLen {
	NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:^{
		[self addBlockEntryWithHostName: hostName port: portNum maskLen: maskLen];
	}];
	[opQueue addOperation: op];
}

- (void)addBlockEntryWithHostName:(NSString*)hostName port:(int)portNum maskLen:(int)maskLen {
	BOOL isIP = [hostName isValidIPAddress];
	BOOL isIPv4 = [hostName isValidIPv4Address];

	if([hostName isEqualToString: @"*"]) {
		[pf addRuleWithIP: nil port: portNum maskLen: 0];
	} else if(isIPv4) { // current we do NOT do ipfw blocking for IPv6
		[pf addRuleWithIP: hostName port: portNum maskLen: maskLen];
	} else if(!isIP && (![self domainIsGoogle: hostName] || isWhitelist)) { // domain name
		// on blacklist blocks where the domain is Google, we don't use ipfw to block
		// because we'd end up blocking more than the user wants (i.e. Search/Reader)
		NSArray* addresses = [self ipAddressesForDomainName: hostName];

		for(int i = 0; i < [addresses count]; i++) {
			NSString* ip = addresses[i];

			[pf addRuleWithIP: ip port: portNum maskLen: maskLen];
		}
	}

	if(hostsBlockingEnabled && ![hostName isEqualToString: @"*"] && !portNum && !isIP) {
		[hostsBlocker addRuleBlockingDomain: hostName];
	}
}

- (void)addBlockEntryFromString:(NSString*)entry {
	// don't do anything with blank hostnames, however they got on the list...
	// otherwise they could end up screwing up the block
	if (![[entry stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		return;
	}

	NSDictionary* hostInfo = [self parseHostString: entry];

	NSString* hostName = hostInfo[@"hostName"];
	NSNumber* portNumObject = hostInfo[@"port"];
	NSNumber* maskLenObject = hostInfo[@"maskLen"];
	int portNum = portNumObject ? [portNumObject intValue] : 0;
	int maskLen = maskLenObject ? [maskLenObject intValue] : 0;

	// we won't block host * (everywhere) without a port number... it's just too likely to be mistaken.
	// Use a whitelist if that's what you want!
	if ([hostName isEqualToString: @"*"] && !portNum) {
		return;
	}

	[self addBlockEntryWithHostName: hostName port: portNum maskLen: maskLen];

	if (isWhitelist && includeLinkedDomains && ![hostName isValidIPAddress]) {
		NSSet* relatedDomains = [WhitelistScraper relatedDomains: hostName];
		[relatedDomains enumerateObjectsUsingBlock:^(NSString* host, BOOL* stop) {
			[self enqueueBlockEntryWithHostName: host port: 0 maskLen: 0];
		}];
	}

	if(![hostName isValidIPAddress] && includeCommonSubdomains) {
		NSArray* commonSubdomains = [self commonSubdomainsForHostName: hostName];

		for(int i = 0; i < [commonSubdomains count]; i++) {
			// we do not pull port, we leave the port number the same as we got it
			hostInfo = [self parseHostString: commonSubdomains[i]];
			hostName = hostInfo[@"hostName"];
			maskLenObject = hostInfo[@"maskLen"];
			maskLen = maskLenObject ? [maskLenObject intValue] : 0;

			[self enqueueBlockEntryWithHostName: hostName port: portNum maskLen: maskLen];
		}
	}
}

- (void)addBlockEntries:(NSArray*)blockList {
	for(int i = 0; i < [blockList count]; i++) {
		NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:^{
			[self addBlockEntryFromString: blockList[i]];
		}];
		[opQueue addOperation: op];
	}
}

- (BOOL)clearBlock {
	[pf stopBlock: false];
	BOOL pfSuccess = ![pf containsSelfControlBlock];

	[hostsBlocker removeSelfControlBlock];
	BOOL hostSuccess = [hostsBlocker writeNewFileContents];
	// Revert the host file blocker's file contents to disk so we can check
	// whether or not it still contains the block (aka we messed up).
	[hostsBlocker revertFileContentsToDisk];
	hostSuccess = hostSuccess && ![hostsBlocker containsSelfControlBlock];

	BOOL clearedSuccessfully = hostSuccess && pfSuccess;

	if(clearedSuccessfully)
		NSLog(@"INFO: Block successfully cleared.");
	else {
		if (!pfSuccess) {
			NSLog(@"WARNING: Error clearing pf block. Tring to clear using force.");
			[pf stopBlock: true];
		}
		if (!hostSuccess) {
			NSLog(@"WARNING: Error removing hostfile block.  Attempting to restore host file backup.");
			[hostsBlocker restoreBackupHostsFile];
		}

		clearedSuccessfully = ![self blockIsActive];

		if ([hostsBlocker containsSelfControlBlock]) {
			NSLog(@"ERROR: Host file backup could not be restored.  This may result in a permanent block.");
		}
		if ([pf containsSelfControlBlock]) {
			NSLog(@"ERROR: Firewall rules could not be cleared.  This may result in a permanent block.");
		}
		if (clearedSuccessfully) {
			NSLog(@"INFO: Firewall rules successfully cleared.");
		}
	}

	[hostsBlocker deleteBackupHostsFile];

	return clearedSuccessfully;
}

- (BOOL)forceClearBlock {
	[pf stopBlock: YES];
	BOOL pfSuccess = ![pf containsSelfControlBlock];

	[hostsBlocker removeSelfControlBlock];
	BOOL hostSuccess = [hostsBlocker writeNewFileContents];
	// Revert the host file blocker's file contents to disk so we can check
	// whether or not it still contains the block (aka we messed up).
	[hostsBlocker revertFileContentsToDisk];
	hostSuccess = hostSuccess && ![hostsBlocker containsSelfControlBlock];

	BOOL clearedSuccessfully = hostSuccess && pfSuccess;

	if(clearedSuccessfully)
		NSLog(@"INFO: Block successfully cleared.");
	else {
		if (!pfSuccess) {
			NSLog(@"ERROR: Error clearing pf block. This may result in a permanent block.");
		}
		if (!hostSuccess) {
			NSLog(@"WARNING: Error removing hostfile block.  Attempting to restore host file backup.");
			[hostsBlocker restoreBackupHostsFile];
		}

		clearedSuccessfully = ![self blockIsActive];

		if ([hostsBlocker containsSelfControlBlock]) {
			NSLog(@"ERROR: Host file backup could not be restored.  This may result in a permanent block.");
		}
		if (clearedSuccessfully) {
			NSLog(@"INFO: Firewall rules successfully cleared.");
		}
	}

	return clearedSuccessfully;
}

- (BOOL)blockIsActive {
	return [hostsBlocker containsSelfControlBlock] || [pf containsSelfControlBlock];
}

- (NSArray*)commonSubdomainsForHostName:(NSString*)hostName {
	NSMutableSet* newHosts = [NSMutableSet set];

	// If the domain ends in facebook.com...  Special case for Facebook because
	// users will often forget to block some of its many mirror subdomains that resolve
	// to different IPs, i.e. hs.facebook.com.  Thanks to Danielle for raising this issue.
	if([hostName hasSuffix: @"facebook.com"]) {
		// pulled list of facebook IP ranges from https://developers.facebook.com/docs/ApplicationSecurity/#facebook_scraper
		// TODO: pull these automatically by running:
		// whois -h whois.radb.net -- '-i origin AS32934' | grep ^route
		NSArray* facebookIPs = @[@"31.13.24.0/21",
								 @"31.13.64.0/18",
								 @"66.220.144.0/20",
								 @"69.63.176.0/20",
								 @"69.171.224.0/19",
								 @"74.119.76.0/22",
								 @"103.4.96.0/22",
								 @"173.252.64.0/18",
								 @"204.15.20.0/22"];

		[newHosts addObjectsFromArray: facebookIPs];
	}
	if ([hostName hasSuffix: @"twitter.com"]) {
		[newHosts addObject: @"api.twitter.com"];
	}

	// Block the domain with no subdomains, if www.domain is blocked
	if([hostName rangeOfString: @"www."].location == 0) {
		[newHosts addObject: [hostName substringFromIndex: 4]];
	} else { // Or block www.domain otherwise
		[newHosts addObject: [@"www." stringByAppendingString: hostName]];
	}

	return [newHosts allObjects];
}

- (NSArray*)ipAddressesForDomainName:(NSString*)domainName {
	NSHost* host = [NSHost hostWithName: domainName];

	if(!host) {
		return @[];
	}

	return [host addresses];
}

- (BOOL)domainIsGoogle:(NSString*)domainName {
	// todo: make this regex not suck
	NSString* googleRegex = @"^([a-z0-9]+\\.)*(google|youtube|picasa|sketchup|blogger|blogspot)\\.([a-z]{1,3})(\\.[a-z]{1,3})?$";
	NSPredicate* googleTester = [NSPredicate
								 predicateWithFormat: @"SELF MATCHES %@",
								 googleRegex
								 ];
	return [googleTester evaluateWithObject: domainName];
}

- (NSDictionary*)parseHostString:(NSString*)hostString {
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	NSString* hostName;

	NSArray* splitString = [hostString componentsSeparatedByString: @"/"];
	hostName = splitString[0];

	NSString* stringToSearchForPort = splitString[0];

	if([splitString count] >= 2) {
		int maskLen = [splitString[1] intValue];

		if(maskLen != 0) { // 0 means we could not parse to int value
			[dict setValue: @(maskLen) forKey: @"maskLen"];
		}

		// we expect the port number to come after the IP/masklen
		stringToSearchForPort = splitString[1];
	}

	splitString = [stringToSearchForPort componentsSeparatedByString: @":"];

	// only if hostName wasn't already split off by the maskLen
	if([stringToSearchForPort isEqualToString: hostName]) {
		hostName = splitString[0];
	}

	if([splitString count] >= 2) {
		int portNum = [splitString[1] intValue];

		if(portNum != 0) { // 0 means we could not parse to int value
			[dict setValue: @(portNum) forKey: @"port"];
		}
	}

	if([hostName isEqualToString: @""]) {
		hostName = @"*";
	}

	[dict setValue: hostName forKey: @"hostName"];

	return dict;
}

@end
