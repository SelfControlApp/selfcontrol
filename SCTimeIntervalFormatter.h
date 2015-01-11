//
//  SCTimeIntervalFormatter.h
//  SelfControl
//
//  Created by Sam Stigler on 10/14/14.
//
//

#import <Foundation/Foundation.h>

/**
 Formats a time interval (provided in seconds wrapped in an NSNumber).
 
 @discussion This is a façade that will allow us to conditionally take advantage of better time
 interval formatting methods as they become available.
 */
@interface SCTimeIntervalFormatter : NSFormatter

@end
