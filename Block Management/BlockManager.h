//
//  BlockManager.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/5/13.
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

#import <Foundation/Foundation.h>
#import "PacketFilter.h"
#import "NSString+IPAddress.h"

@class SCBlockEntry;
@class HostFileBlockerSet;

@interface BlockManager : NSObject {
	NSOperationQueue* opQueue;
	PacketFilter* pf;
	HostFileBlockerSet* hostBlockerSet;
	BOOL hostsBlockingEnabled;
	BOOL isAllowlist;
	BOOL allowLocal;
	BOOL includeCommonSubdomains;
	BOOL includeLinkedDomains;
    NSMutableSet* addedBlockEntries;
}

- (BlockManager*)initAsAllowlist:(BOOL)allowlist;
- (BlockManager*)initAsAllowlist:(BOOL)allowlist allowLocal:(BOOL)local;
- (BlockManager*)initAsAllowlist:(BOOL)allowlist allowLocal:(BOOL)local includeCommonSubdomains:(BOOL)blockCommon;
- (BlockManager*)initAsAllowlist:(BOOL)allowlist allowLocal:(BOOL)local includeCommonSubdomains:(BOOL)blockCommon includeLinkedDomains:(BOOL)includeLinked;

- (void)enterAppendMode;
- (void)finishAppending;
- (void)prepareToAddBlock;
- (void)finalizeBlock;
- (void)addBlockEntryFromString:(NSString*)entry;
- (void)addBlockEntry:(SCBlockEntry*)entry;
- (void)addBlockEntriesFromStrings:(NSArray<NSString*>*)blockList;
- (BOOL)clearBlock;
- (BOOL)forceClearBlock;
- (BOOL)blockIsActive;

- (NSArray*)commonSubdomainsForHostName:(NSString*)hostName;
+ (NSArray*)ipAddressesForDomainName:(NSString*)domainName;
- (BOOL)domainIsGoogle:(NSString*)domainName;

@end
