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
#import "IPFirewall.h"
#import "LaunchctlHelper.h"
#import "SelfControlUtilities.h"
#import <unistd.h>
#import <Cocoa/Cocoa.h>
#import <sysexits.h>
#import "HostFileBlocker.h"
#import "SelfControlCommon.h"

// These don't comply with the "end instance variables with an underscore" rule
// because they aren't instance variables.  Note this file is, although in
// Objective-C, not a class.  It contains only functions.
NSUserDefaults* defaults;
NSArray* domainList;

// Reads the domain block list from the defaults for SelfControl, and adds deny
// rules for all of the IPs (or the A DNS record IPS for doamin names) to the
// ipfw firewall.
void addRulesToFirewall(signed long long int controllingUID);

// Removes from ipfw all rules that were created by SelfControl.
void removeRulesFromFirewall(signed long long int controllingUID);

// Returns an autoreleased NSSet containing all IP adresses for evaluated
// "common subdomains" for the specified hostname
NSSet* getEvaluatedHostNamesFromCommonSubdomains(NSString* hostName, int port);

// Checks the defaults system to see whether the user wants their web browser
// caches cleared, and deletes the specific cache folders for a few common
// web browsers if it is required.
void clearCachesIfRequested(signed long long int controllingUID);

// Prints out the given status code to stdout using printf
void printStatus(int status);

// Parses hostName, to find a mask length (for IP ranges) and port number, if
// specified.  Returns by reference baseName, which is hostName without mask
// length or port number, and the mask length and port number unless they were
// not specified, in which case they will be initialized to -1.
void parseHost(NSString* hostName, NSString** baseName, int* maskLength, int* portNumber);

// Removes block via setting the defaults, removing the lock file, host file rules and ipfw
// rules, unloading the org.eyebeam.SelfControl item, and deleting user caches if requested.
void removeBlock(signed long long int controllingUID);