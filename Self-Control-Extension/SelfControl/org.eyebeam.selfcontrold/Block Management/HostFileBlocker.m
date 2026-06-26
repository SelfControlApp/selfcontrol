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

- (instancetype)init {
    return [self initWithPath: kHostFileBlockerPath];
}
- (instancetype)initWithPath:(NSString*)path {
	if(self = [super init]) {
        hostFilePath = path;
		fileMan = [[NSFileManager alloc] init];
		strLock = [[NSLock alloc] init];
		newFileContents = [NSMutableString stringWithContentsOfFile: hostFilePath usedEncoding: &stringEnc error: NULL];
		if(!newFileContents) {
			// if we lost our hosts file, replace it with the OS X default
			newFileContents = [NSMutableString stringWithString: kDefaultHostsFileContents];
		}
	}

	return self;
}

+ (BOOL)blockFoundInHostsFile {
    // last try if we can't find a block anywhere: check the host file, and see if a block is in there
    NSString* hostFileContents = [NSString stringWithContentsOfFile: kHostFileBlockerPath encoding: NSUTF8StringEncoding error: NULL];
    if(hostFileContents != nil && [hostFileContents rangeOfString: kHostFileBlockerSelfControlHeader].location != NSNotFound) {
        return YES;
    }
    
    return NO;
}

- (void)revertFileContentsToDisk {
	[strLock lock];

	newFileContents = [NSMutableString stringWithContentsOfFile: hostFilePath usedEncoding: &stringEnc error: NULL];
	if(!newFileContents) {
		newFileContents = [NSMutableString stringWithString: kDefaultHostsFileContents];
	}

	[strLock unlock];
}

- (BOOL)writeNewFileContents {
	[strLock lock];

	BOOL ret = [newFileContents writeToFile: hostFilePath atomically: YES encoding: stringEnc error: NULL];

	[strLock unlock];
	return ret;
}

- (NSString*)backupHostFilePath {
    return [hostFilePath stringByAppendingPathExtension: @"bak"];
}

- (BOOL)createBackupHostsFile {
	[self deleteBackupHostsFile];

	if (![fileMan fileExistsAtPath: hostFilePath]) {
		[kDefaultHostsFileContents writeToFile: hostFilePath atomically:true encoding: NSUTF8StringEncoding error: NULL];
	}

	if(![fileMan isReadableFileAtPath: hostFilePath] || [fileMan fileExistsAtPath: [self backupHostFilePath]]) {
		return NO;
	}

	return [fileMan copyItemAtPath: hostFilePath toPath: [self backupHostFilePath] error: nil];
}

- (BOOL)deleteBackupHostsFile {
	if(![fileMan isDeletableFileAtPath: [self backupHostFilePath]])
		return NO;

	return [fileMan removeItemAtPath: [self backupHostFilePath] error: nil];
}

- (BOOL)restoreBackupHostsFile {
    NSString* backupPath = [self backupHostFilePath];
    
	if(![fileMan removeItemAtPath: hostFilePath error: nil])
		return NO;
	if(![fileMan isReadableFileAtPath: backupPath] || ![fileMan moveItemAtPath: backupPath toPath: hostFilePath error: nil])
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
    NSUInteger deleteRangeStart = startRange.location;
    NSUInteger deleteRangeLength;

    // there are usually newlines placed before/after the header/footer
    // we should remove them if possible to keep the hosts file looking tidy
    // only remove the previous character if we aren't at the start of the file (or we'll crash)
    if (deleteRangeStart > 0) {
        unichar prevChar = [newFileContents characterAtIndex: deleteRangeStart - 1];
        // if the previous character isn't a newline, don't delete it
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember: prevChar]) {
            deleteRangeStart--;
        }
    }
        
    NSUInteger maxDeleteLength = [newFileContents length] - deleteRangeStart;
    // if we lost the block footer somehow... well, crap, just delete everything below the header
    // this isn't ideal and we might bork other stuff, but it's better than leaving the block on
    if (endRange.location == NSNotFound) {
        deleteRangeLength = maxDeleteLength;
    } else {
        deleteRangeLength = MIN(maxDeleteLength, (endRange.location + endRange.length) - deleteRangeStart);
        
        // as above, look at removing the excess newline if possible
        if (deleteRangeLength < maxDeleteLength) {
            unichar nextChar = [newFileContents characterAtIndex: deleteRangeStart + deleteRangeLength];
            // if the next character isn't a newline, don't delete it
            if ([[NSCharacterSet newlineCharacterSet] characterIsMember: nextChar]) {
                deleteRangeLength++;
            }
        }
    }

	NSRange deleteRange = NSMakeRange(deleteRangeStart, deleteRangeLength);

	[newFileContents deleteCharactersInRange: deleteRange];

	[strLock unlock];
}

@end
