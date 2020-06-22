//
//  AllowlistScraper.h
//  SelfControl
//
//  Created by Charles Stigler on 10/7/14.
//
//

#import <Foundation/Foundation.h>

@interface AllowlistScraper : NSObject

+ (NSSet*)relatedDomains:(NSString*)domain;

@end
