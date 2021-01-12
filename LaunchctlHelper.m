//
//  SCLaunchctlHelper.m
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

#import "LaunchctlHelper.h"

@implementation LaunchctlHelper

+ (int)unloadLaunchdJobWithPlistAt:(NSString*)pathToLaunchdPlist {
	NSTask* task = [[NSTask alloc] init];
	[task setLaunchPath: @"/bin/launchctl"];
	[task setArguments: @[@"unload",
						  @"-w",
						  pathToLaunchdPlist]];
	[task launch];
	[task waitUntilExit];
	return [task terminationStatus];
}

@end
