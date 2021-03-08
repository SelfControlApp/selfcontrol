//
//  HostFileBlocker.h
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

#import <Cocoa/Cocoa.h>

@protocol HostFileBlocker

- (BOOL)deleteBackupHostsFile;

- (void)revertFileContentsToDisk;

- (BOOL)writeNewFileContents;

- (void)addSelfControlBlockHeader;

- (void)addSelfControlBlockFooter;

- (BOOL)createBackupHostsFile;

- (BOOL)restoreBackupHostsFile;

- (void)addRuleBlockingDomain:(NSString*)domainName;
- (void)appendExistingBlockWithRuleForDomain:(NSString*)domainName;

- (BOOL)containsSelfControlBlock;

- (void)removeSelfControlBlock;

@end


@interface HostFileBlocker : NSObject <HostFileBlocker> {
    NSString* hostFilePath;
    
    NSLock* strLock;
    NSMutableString* newFileContents;
    NSStringEncoding stringEnc;
    NSFileManager* fileMan;
}

- (instancetype)initWithPath:(NSString*)path;

+ (BOOL)blockFoundInHostsFile;

@end
