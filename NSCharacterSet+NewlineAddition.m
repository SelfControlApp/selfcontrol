//
//  NSCharacterSet+NewlineAddition.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/2/09.
//  Copyright 2009 Harvard-Westlake Student. All rights reserved.
//

#import "NSCharacterSet+NewlineAddition.h"


@implementation NSCharacterSet (NewlineAddition)

+ (NSCharacterSet*)newlineCharacterSet {
  static NSCharacterSet *newlineCharacterSet = nil;
  if (newlineCharacterSet == nil) {
    NSMutableCharacterSet *tmpSet = [[NSCharacterSet whitespaceCharacterSet] mutableCopy];
    [tmpSet invert];
    [tmpSet formIntersectionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    newlineCharacterSet = [tmpSet copy];
    [tmpSet release];
  }
  return newlineCharacterSet;
}

@end
