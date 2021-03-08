//
//  HostFileBlockerSet.m
//  SelfControl
//
//  Created by Charlie Stigler on 3/7/21.
//

#import "HostFileBlockerSet.h"

@implementation HostFileBlockerSet

- (instancetype)init {
    return [self initWithCommonFiles];
}
- (instancetype)initWithCommonFiles {
    NSFileManager* fileMan = [NSFileManager defaultManager];
    NSArray<NSString*>* commonBackupHostFilePaths = @[
        // Juniper Pulse
        @"/etc/pulse-hosts.bak",
        @"/etc/jnpr-pulse-hosts.bak",
        @"/etc/pulse.hosts.bak",
        @"/etc/jnpr-nc-hosts.bak",
        
        // Cisco AnyConnect
        @"/etc/hosts.ac"
    ];
    
    NSMutableArray* hostFileBlockers = [NSMutableArray arrayWithCapacity: commonBackupHostFilePaths.count + 1];
    
    _defaultBlocker = [HostFileBlocker new];
    [hostFileBlockers addObject: _defaultBlocker];
    
    for (NSString* path in commonBackupHostFilePaths) {
        if ([fileMan isReadableFileAtPath: path]) {
            NSLog(@"INFO: found backup VPN host file at %@", path);
            HostFileBlocker* blocker = [[HostFileBlocker alloc] initWithPath: path];
            [hostFileBlockers addObject: blocker];
        }
    }
    
    _blockers = hostFileBlockers;
    
    return self;
}

- (BOOL)deleteBackupHostsFile {
    BOOL ret = YES;
    for (HostFileBlocker* blocker in self.blockers) {
        ret = ret && [blocker deleteBackupHostsFile];
    }
    return ret;
}

- (void)revertFileContentsToDisk {
    for (HostFileBlocker* blocker in self.blockers) {
        [blocker revertFileContentsToDisk];
    }
}

- (BOOL)writeNewFileContents {
    BOOL ret = YES;
    for (HostFileBlocker* blocker in self.blockers) {
        ret = ret && [blocker writeNewFileContents];
    }
    return ret;
}

- (void)addSelfControlBlockHeader {
    for (HostFileBlocker* blocker in self.blockers) {
        [blocker addSelfControlBlockHeader];
    }
}

- (void)addSelfControlBlockFooter {
    for (HostFileBlocker* blocker in self.blockers) {
        [blocker addSelfControlBlockFooter];
    }
}

- (BOOL)createBackupHostsFile {
    BOOL ret = YES;
    for (HostFileBlocker* blocker in self.blockers) {
        ret = ret && [blocker createBackupHostsFile];
    }
    return ret;
}

- (BOOL)restoreBackupHostsFile {
    BOOL ret = YES;
    for (HostFileBlocker* blocker in self.blockers) {
        ret = ret && [blocker restoreBackupHostsFile];
    }
    return ret;
}

- (void)addRuleBlockingDomain:(NSString*)domainName {
    for (HostFileBlocker* blocker in self.blockers) {
        [blocker addRuleBlockingDomain: domainName];
    }
}
- (void)appendExistingBlockWithRuleForDomain:(NSString*)domainName {
    for (HostFileBlocker* blocker in self.blockers) {
        [blocker appendExistingBlockWithRuleForDomain: domainName];
    }
}

- (BOOL)containsSelfControlBlock {
    BOOL ret = NO;
    for (HostFileBlocker* blocker in self.blockers) {
        ret = ret || [blocker containsSelfControlBlock];
    }
    return ret;
}

- (void)removeSelfControlBlock {
    for (HostFileBlocker* blocker in self.blockers) {
        [blocker removeSelfControlBlock];
    }
}

@end
