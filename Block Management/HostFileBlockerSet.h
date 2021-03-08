//
//  HostFileBlockerSet.h
//  SelfControl
//
//  Created by Charlie Stigler on 3/7/21.
//

#import <Foundation/Foundation.h>
#import "HostFileBlocker.h"

NS_ASSUME_NONNULL_BEGIN

@interface HostFileBlockerSet : NSObject <HostFileBlocker>

@property (readonly) NSArray<HostFileBlocker*>* blockers;
@property (readonly) HostFileBlocker* defaultBlocker;

@end

NS_ASSUME_NONNULL_END
