//
//  SCLaunchctlHelper.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/13/09.
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

#import <Foundation/Foundation.h>

// A simple utility class to deal with launchd jobs by calling the launchctl
// command-line tool.  Each method corresponds to a launchctl subcommand.
@interface LaunchctlHelper : NSObject {
}

// Calls the launchctl command-line tool installed on all newer Mac OS X
// systems to load into the launchd system a new job.  The specifications
// for this job are provided in the plist at the given path.  Returns the exit
// status code of launchctl.
+ (int)loadLaunchdJobWithPlistAt:(NSString*)pathToLaunchdPlist;

// Calls the launchctl command-line tool installed on all newer Mac OS X
// systems to unload a job from the launchd system, which was loaded from the
// plist at the given path.  Returns the exit status code of launchctl.
+ (int)unloadLaunchdJobWithPlistAt:(NSString*)pathToLaunchdPlist;

@end
