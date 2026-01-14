//
//  AllowlistScraper.h
//  SelfControl
//
//  Created by Charles Stigler on 10/7/14.
//
//

#import <Foundation/Foundation.h>

@class SCBlockEntry;

@interface AllowlistScraper : NSObject

+ (NSSet<SCBlockEntry*>*)relatedBlockEntries:(NSString*)domain;

@end
