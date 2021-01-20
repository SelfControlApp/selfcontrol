//
//  SCBlockFileReaderWriter.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import "SCBlockFileReaderWriter.h"

@implementation SCBlockFileReaderWriter

+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo errorDescription:(NSString**)errDescriptionRef {
    NSDictionary* saveDict = @{@"HostBlacklist": [blockInfo objectForKey: @"Blocklist"],
                               @"BlockAsWhitelist": [blockInfo objectForKey: @"BlockAsWhitelist"]};

    NSString* saveDataErr;
    NSData* saveData = [NSPropertyListSerialization dataFromPropertyList: saveDict format: NSPropertyListBinaryFormat_v1_0 errorDescription: &saveDataErr];
    if (saveDataErr != nil) {
        *errDescriptionRef = saveDataErr;
        return NO;
    }

    if (![saveData writeToURL: targetFileURL atomically: YES]) {
        NSLog(@"ERROR: Failed to write blocklist to URL %@", targetFileURL);
        return NO;
    }
    
    // for prettiness sake, attempt to hide the file extension
    NSDictionary* attribs = @{NSFileExtensionHidden: @YES};
    [[NSFileManager defaultManager] setAttributes: attribs ofItemAtPath: [targetFileURL path] error: NULL];
    
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
