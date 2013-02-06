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
#import "IPFirewall.h"
#import "HostFileBlocker.h"
#import "NSString+IPAddress.h"

@interface BlockManager : NSObject {
  NSOperationQueue* opQueue;
  IPFirewall* ipfw;
  HostFileBlocker* hostsBlocker;
  BOOL hostsBlockingEnabled;
  BOOL isWhitelist;
  BOOL allowLocal;
  BOOL includeCommonSubdomains;
}

- (BlockManager*)initAsWhitelist:(BOOL)whitelist;
- (BlockManager*)initAsWhitelist:(BOOL)whitelist allowLocal:(BOOL)local;
- (BlockManager*)initAsWhitelist:(BOOL)whitelist allowLocal:(BOOL)local includeCommonSubdomains:(BOOL)blockCommon;

- (void)prepareToAddBlock;
- (void)finalizeBlock;
- (void)addBlockEntryFromString:(NSString*)entry;
- (void)addBlockEntryWithHostName:(NSString*)hostName port:(int)portNum maskLen:(int)maskLen;
- (void)addBlockEntries:(NSArray*)blockList;

- (NSArray*)commonSubdomainsForHostName:(NSString*)hostName;
- (NSArray*)ipAddressesForDomainName:(NSString*)domainName;
- (NSString*)domainIsGoogle:(NSString*)domainName;
- (NSDictionary*)parseHostString:(NSString*)hostString;

@end
