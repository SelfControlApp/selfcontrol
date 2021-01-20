//
//  SCMiscUtilities.h
//  SelfControl
//
//  Created by Charles Stigler on 07/07/2018.
//

#import <Foundation/Foundation.h>
#import "SCMigrationUtilities.h"

// Holds utility methods for use throughout SelfControl


@interface SCMiscUtilities : NSObject

+ (dispatch_source_t)createDebounceDispatchTimer:(double) debounceTime queue:(dispatch_queue_t)queue block:(dispatch_block_t)block;

+ (NSArray<NSString*>*) cleanBlocklistEntry:(NSString*)rawEntry;

+ (NSDictionary*) defaultsDictForUser:(uid_t)controllingUID;

+ (NSArray<NSURL*>*)allUserHomeDirectoryURLs:(NSError**)errPtr;

+ (NSError*)clearBrowserCaches;

+ (BOOL)errorIsAuthCanceled:(NSError*)err;


@end
