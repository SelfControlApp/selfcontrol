//
//  HostFileBlocker.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/28/09.
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

#import "HostFileBlocker.h"

NSString* const kHostFileBlockerPath = @"/etc/hosts";
NSString* const kHostFileBlockerSelfControlHeader = @"# BEGIN SELFCONTROL BLOCK";
NSString* const kHostFileBlockerSelfControlFooter = @"# END SELFCONTROL BLOCK";
NSString* const kDefaultHostsFileContents = @"##\n"
"# Host Database\n"
"#\n"
"# localhost is used to configure the loopback interface\n"
"# when the system is booting.  Do not change this entry.\n"
"##\n"
"127.0.0.1	localhost\n"
"255.255.255.255	broadcasthost\n"
"::1             localhost\n"
"fe80::1%lo0	localhost\n\n";

@implementation HostFileBlocker

- (HostFileBlocker*)init {
	if(self = [super init]) {
		fileMan = [[NSFileManager alloc] init];
		strLock = [[NSLock alloc] init];
		newFileContents = [NSMutableString stringWithContentsOfFile: kHostFileBlockerPath usedEncoding: &stringEnc error: NULL];
		if(!newFileContents) {
			// if we lost our hosts file, replace it with the OS X default
			newFileContents = [NSMutableString stringWithString: kDefaultHostsFileContents];
		}
	}

	return self;
}

- (void)revertFileContentsToDisk {
	[strLock lock];

	newFileContents = [NSMutableString stringWithContentsOfFile: kHostFileBlockerPath usedEncoding: &stringEnc error: NULL];

	if(!newFileContents) {
		newFileContents = [NSMutableString stringWithString: kDefaultHostsFileContents];
	}

	[strLock unlock];
}

- (BOOL)writeNewFileContents {
	[strLock lock];

	BOOL ret = [newFileContents writeToFile: kHostFileBlockerPath atomically: YES encoding: stringEnc error: NULL];

	[strLock unlock];
	return ret;
}

- (BOOL)createBackupHostsFile {
	[self deleteBackupHostsFile];

	if (![fileMan fileExistsAtPath: @"/etc/hosts"]) {
		[kDefaultHostsFileContents writeToFile: @"/etc/hosts" atomically:true encoding: NSUTF8StringEncoding error: NULL];
	}

	if(![fileMan isReadableFileAtPath: @"/etc/hosts"] || [fileMan fileExistsAtPath: @"/etc/hosts.bak"]) {
		return NO;
	}

	return [fileMan copyItemAtPath: @"/etc/hosts" toPath: @"/etc/hosts.bak" error: nil];
}

- (BOOL)deleteBackupHostsFile {
	if(![fileMan isDeletableFileAtPath: @"/etc/hosts.bak"])
		return NO;

	return [fileMan removeItemAtPath: @"/etc/hosts.bak" error: nil];
}

- (BOOL)restoreBackupHostsFile {
	if(![fileMan removeItemAtPath: @"/etc/hosts" error: nil])
		return NO;
	if(![fileMan isReadableFileAtPath: @"/etc/hosts.bak"] || ![fileMan moveItemAtPath: @"/etc/hosts.bak" toPath: @"/etc/hosts" error: nil])
		return NO;

	return YES;
}

- (void)addSelfControlBlockHeader {
	[strLock lock];
	[newFileContents appendString: @"\n"];
	[newFileContents appendString: kHostFileBlockerSelfControlHeader];
	[newFileContents appendString: @"\n"];
	[strLock unlock];
}

- (void)addSelfControlBlockFooter {
	[strLock lock];
	[newFileContents appendString: kHostFileBlockerSelfControlFooter];
	[newFileContents appendString: @"\n"];
	[strLock unlock];
}

- (NSArray<NSString*>*)ruleStringsToBlockDomain:(NSString*)domainName {
    return @[
        [NSString stringWithFormat: @"0.0.0.0\t%@\n", domainName],
        [NSString stringWithFormat: @"::\t%@\n", domainName]
    ];
}

- (void)addRuleBlockingDomain:(NSString*)domainName {
	[strLock lock];
    NSLog(@"host file blocker: add rule to block domain %@", domainName);
    NSArray<NSString*>* ruleStrings = [self ruleStringsToBlockDomain: domainName];
    for (NSString* ruleString in ruleStrings) {
        [newFileContents appendString: ruleString];
    }
	[strLock unlock];
}

- (void)appendExistingBlockWithRuleForDomain:(NSString*)domainName {
    [strLock lock];
    NSRange footerLocation = [newFileContents rangeOfString: kHostFileBlockerSelfControlFooter];
    if (footerLocation.location == NSNotFound) {
        // we can't append if a block isn't in the file already!
        NSLog(@"WARNING: can't append to host block because footer can't be found");
    } else {
        // combine the rule strings and insert em all at once to make the math easier
        NSArray<NSString*>* ruleStrings = [self ruleStringsToBlockDomain: domainName];

        NSMutableString* combinedRuleString = [NSMutableString string];
        for (NSString* ruleString in ruleStrings) {
            [combinedRuleString appendString: ruleString];
        }
                
        [newFileContents insertString: combinedRuleString atIndex: footerLocation.location];
    }
    [strLock unlock];
}

- (BOOL)containsSelfControlBlock {
	[strLock lock];

    BOOL ret = ([newFileContents rangeOfString: kHostFileBlockerSelfControlHeader].location != NSNotFound);

	[strLock unlock];
	return ret;
}

- (void)removeSelfControlBlock {
	if(![self containsSelfControlBlock])
		return;

	[strLock lock];

	NSRange startRange = [newFileContents rangeOfString: kHostFileBlockerSelfControlHeader];
	NSRange endRange = [newFileContents rangeOfString: kHostFileBlockerSelfControlFooter];

    // generate a delete range that properly removes the block from the hosts file
    // the -1 and +1 are to remove the newlines before/after the header/footer
    // the MAX/MIN prevent us from trying to delete beyond the file boundaries
    NSUInteger deleteRangeStart = MAX(0, startRange.location - 1);
    NSUInteger deleteRangeLength;
    // if we lost the block footer somehow... well, crap, just delete everything below the header
    if (endRange.location == NSNotFound) {
        deleteRangeLength = [newFileContents length] - deleteRangeStart;
    } else {
        deleteRangeLength = MIN([newFileContents length] - deleteRangeStart, (endRange.location + endRange.length) - deleteRangeStart + 1);
    }

	NSRange deleteRange = NSMakeRange(deleteRangeStart, deleteRangeLength);

	[newFileContents deleteCharactersInRange: deleteRange];

	[strLock unlock];
}

@end
