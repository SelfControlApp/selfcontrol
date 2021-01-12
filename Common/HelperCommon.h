//
//  HelperCommonFunctions.h
//  SelfControl
//
//  Created by Charlie Stigler on 07/13/09.
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

// All the functions etc. formerly used for HelperMain are now separated into this file.
// This is so that another helper tool can be created that easily uses those same functions.

// imports for all helper tools
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "LaunchctlHelper.h"
#import <unistd.h>
#import <Cocoa/Cocoa.h>
#import <sysexits.h>
#import "HostFileBlocker.h"
#import "SelfControlCommon.h"
#import "SCUtilities.h"
#import "SCSettings.h"

// Reads the domain block list from the settings for SelfControl, and adds deny
// rules for all of the IPs (or the A DNS record IPS for doamin names) to the
// ipfw firewall.
void addRulesToFirewall();

// Removes from ipfw all rules that were created by SelfControl.
void removeRulesFromFirewall();

// Returns an autoreleased NSSet containing all IP adresses for evaluated
// "common subdomains" for the specified hostname
NSSet* getEvaluatedHostNamesFromCommonSubdomains(NSString* hostName, int port);

// Checks the settings system to see whether the user wants their web browser
// caches cleared, and deletes the specific cache folders for a few common
// web browsers if it is required.
void clearCachesIfRequested(uid_t controllingUID);

// Clear only the caches for browsers
void clearBrowserCaches(uid_t controllingUID);

// Clear only the OS-level DNS cache
void clearOSDNSCache(void);

// Prints out the given status code to stdout using printf
void printStatus(int status);

// Removes block via settings, host file rules and ipfw rules,
// deleting user caches if requested, and migrating legacy settings.
void removeBlock(uid_t controllingUID);

void sendConfigurationChangedNotification(void);

// makes sure the secured settings finish syncing
// before calling exit with the given status
// if there's any chance settings could have been modified, we should
// always call this instead of plain exit() to make sure settings aren't left unsynced!
// this waits for the settings to sync before returning, so may be slow
void syncSettingsAndExit(SCSettings* settings, int status);
