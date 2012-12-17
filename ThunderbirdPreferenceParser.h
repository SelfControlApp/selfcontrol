//
//  ThunderbirdPreferenceParser.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/17/09.
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

// A class designed to provide all necessary methods for parsing the incoming
// and outgoing mail hostnames from Thunderbird configuration files, and made
// to be easily extensible in case further configuration information is required.
@interface ThunderbirdPreferenceParser : NSObject {
}

// Returns an autoreleased instance of NSString containing the full, absolute
// path to the Thunderbird support folder (usually ~/Library/Thunderbird)
+ (NSString*)pathToSupportFolder;

// Returns YES if Thunderbird is detected as being installed (opened at least
// once, and therefore preferences initialized) on the current system, or NO
// if Thunderbird's preferences were not found.
+ (BOOL)thunderbirdIsInstalled;

// Returns an autoreleased instance of NSString containing the full, absolute
// path to the Thunderbird default profile folder, or the profile named "default"
// if no profile folder is marked as default, or the first profile if no folder
// is named "default".  Returns nil if no profiles exist.
+ (NSString*)pathToDefaultProfile;

// Returns an autoreleased instance of NSString containing the full, absolute
// path to the Thunderbird prefs.js for the default profile (see
// PathToDefaultProfile for details on how the "default profile" is determined)
+ (NSString*)pathToPrefsJsFile;

// Returns an autoreleased instance of NSArray containing all incoming hostnames
// for the Thunderbird default profile (see PathToDefaultProfile for details on
// how the "default profile" is determined)
+ (NSArray*)incomingHostnames;

// Returns an autoreleased instance of NSArray containing all outgoing hostnames
// for the Thunderbird default profile (see PathToDefaultProfile for details on
// how the "default profile" is determined)
+ (NSArray*)outgoingHostnames;

@end