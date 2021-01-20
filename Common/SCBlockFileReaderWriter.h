//
//  SCBlockFileReaderWriter.h
//  SelfControl
//
//  Created by Charlie Stigler on 1/19/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCBlockFileReaderWriter : NSObject

// read and write saved block files
+ (BOOL)writeBlocklistToFileURL:(NSURL*)targetFileURL blockInfo:(NSDictionary*)blockInfo errorDescription:(NSString**)errDescriptionRef;
+ (NSDictionary*)readBlocklistFromFile:(NSURL*)fileURL;

@end

NS_ASSUME_NONNULL_END
