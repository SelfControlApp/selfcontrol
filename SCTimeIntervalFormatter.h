//
//  SCTimeIntervalFormatter.h
//  SelfControl
//
//  Created by Sam Stigler on 10/14/14.
//
//

#import <Foundation/Foundation.h>

/**
 Formats a time interval (provided in seconds wrapped in an NSNumber) using the following format 
 template:
 0 minutes
 15 minutes
 30 minutes
 45 minutes
 1 hour
 1 hour, 15 minutes
 15 hours, 30 minutes
 23 hours, 45 minutes
 1 day
 
 @discussion This is a façade that will allow us to conditionally take advantage of OS X 10.10 
 Yosemite's new @c NSDateIntervalFormatter when it is available.
 */
@interface SCTimeIntervalFormatter : NSFormatter

@end
