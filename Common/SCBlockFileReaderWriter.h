//
//  SCBlockFileReaderWriter.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// read and write saved .selfcontrol block files
@interface SCBlockFileReaderWriter : NSObject

// Writes out a saved .selfcontrol blocklist file to the file system
// containing the block info (blocklist + whitelist setting) defined
// in blockInfo.
+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo error:(NSError*_Nullable*_Nullable)errRef;

// reads in a saved .selfcontrol blocklist file and returns
// an NSDictionary with the block settings contained
// (properties are Blocklist and BlockAsWhitelist)
+ (NSDictionary*)readBlocklistFromFile:(NSURL*)fileURL;

@end

NS_ASSUME_NONNULL_END
