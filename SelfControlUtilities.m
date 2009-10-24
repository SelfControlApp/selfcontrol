//
//  VersionChecker.m
//  SelfControl
//
//  Created by Charlie Stigler on 4/3/09.
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

#import "SelfControlUtilities.h"

@implementation SelfControlUtilities

+ (void)getSystemVersionMajor:(unsigned *)major
                        minor:(unsigned *)minor
                       bugFix:(unsigned *)bugFix;
{
  OSErr err;
  SInt32 systemVersion, versionMajor, versionMinor, versionBugFix;
  if ((err = Gestalt(gestaltSystemVersion, &systemVersion)) != noErr) goto fail;
  if (systemVersion < 0x1040)
  {
    if (major) *major = ((systemVersion & 0xF000) >> 12) * 10 +
      ((systemVersion & 0x0F00) >> 8);
    if (minor) *minor = (systemVersion & 0x00F0) >> 4;
    if (bugFix) *bugFix = (systemVersion & 0x000F);
  }
  else
  {
    if ((err = Gestalt(gestaltSystemVersionMajor, &versionMajor)) != noErr) goto fail;
    if ((err = Gestalt(gestaltSystemVersionMinor, &versionMinor)) != noErr) goto fail;
    if ((err = Gestalt(gestaltSystemVersionBugFix, &versionBugFix)) != noErr) goto fail;
    if (major) *major = versionMajor;
    if (minor) *minor = versionMinor;
    if (bugFix) *bugFix = versionBugFix;
  }
  
  return;
  
fail:
  NSLog(@"Unable to obtain system version: %ld", (long)err);
  if (major) *major = 10;
  if (minor) *minor = 0;
  if (bugFix) *bugFix = 0;
}

@end
