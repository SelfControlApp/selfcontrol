//
//  SCBlockFileReaderWriter.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import "SCBlockFileReaderWriter.h"

@implementation SCBlockFileReaderWriter

+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo error:(NSError**)errRef {
    NSDictionary* saveDict = @{@"HostBlacklist": [blockInfo objectForKey: @"Blocklist"],
                               @"BlockAsWhitelist": [blockInfo objectForKey: @"BlockAsWhitelist"]};

    NSData* saveData = [NSPropertyListSerialization dataWithPropertyList: saveDict format: NSPropertyListBinaryFormat_v1_0 options: 0 error: errRef];
    if (*errRef != nil) {
        return NO;
    }

    if (![saveData writeToURL: targetFileURL atomically: YES]) {
        NSLog(@"ERROR: Failed to write blocklist to URL %@", targetFileURL);
        *errRef = [SCErr errorWithCode: 106];
        return NO;
    }
    
    // for prettiness sake, attempt to hide the file extension
    NSDictionary* attribs = @{NSFileExtensionHidden: @YES};
    [[NSFileManager defaultManager] setAttributes: attribs ofItemAtPath: [targetFileURL path] error: errRef];
    
    return YES;
}

+ (NSDictionary*)readBlocklistFromFile:(NSURL*)fileURL {
    NSDictionary* openedDict = [NSDictionary dictionaryWithContentsOfURL: fileURL];
    
    if (openedDict == nil || openedDict[@"HostBlacklist"] == nil || openedDict[@"BlockAsWhitelist"] == nil) {
        NSLog(@"ERROR: Could not read a valid block from file %@", fileURL);
        return nil;
    }
    
    return @{
        @"Blocklist": openedDict[@"HostBlacklist"],
        @"BlockAsWhitelist": openedDict[@"BlockAsWhitelist"]
    };
}

@end
