//
//  HostImporter.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/16/09.
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


#import <Cocoa/Cocoa.h>
#import "ThunderbirdPreferenceParser.h"

// A small class to handle getting the mail hostnames from different mail
// programs (just Mail and Thunderbird currently).
@interface HostImporter : NSObject {
}

+ (NSArray*)commonDistractingWebsites;
+ (NSArray*)newsAndPublications;

// Returns an autoreleased instance of NSArray containing all incoming hostnames
// imported from the user's instance of Mail.app
+ (NSArray*)incomingMailHostnamesFromMail;

// Returns an autoreleased instance of NSArray containing all outgoing hostnames
// imported from the user's instance of Mail.app
+ (NSArray*)outgoingMailHostnamesFromMail;

+ (NSArray*)incomingMailHostnamesFromMailMate;
+ (NSArray*)outgoingMailHostnamesFromMailMate;

// Returns an autoreleased instance of NSArray containing all incoming hostnames
// imported from the default profile of the user's instance of Thunderbird
+ (NSArray*)incomingMailHostnamesFromThunderbird;

// Returns an autoreleased instance of NSArray containing all outgoing hostnames
// imported from the default profile of the user's instance of Thunderbird
+ (NSArray*)outgoingMailHostnamesFromThunderbird;

@end