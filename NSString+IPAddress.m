//
//  NSString+IPAddress.m
//  SelfControl
//
//  Created by Charlie Stigler on 2/5/13.
//  Copyright 2009 Eyebeam.

// This file is part of SelfControl.
//
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "NSString+IPAddress.h"

@implementation NSString (IPAddress)

// These methods adapted from code posted by Evan Schoenberg to Stack Overflow
// and licensed under the Attribution-ShareAlike 3.0 Unported license
// http://stackoverflow.com/questions/1679152/how-to-validate-an-ip-address-with-regular-expression-in-objective-c

- (BOOL)isValidIPv4Address {  
  struct in_addr throwaway;
  int success = inet_pton(AF_INET, [self UTF8String], &throwaway);
  
  return (success == 1);
}

- (BOOL)isValidIPv6Address {
  struct in6_addr throwaway;
  int success = inet_pton(AF_INET6, [self UTF8String], &throwaway);
  
  return (success == 1);
}

- (BOOL)isValidIPAddress {
  return ([self isValidIPv4Address] || [self isValidIPv6Address]);
}

@end
