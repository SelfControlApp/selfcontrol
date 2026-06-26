//
//  ThunderbirdPreferenceParser.m
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



#import "ThunderbirdPreferenceParser.h"

NSString* const kThunderbirdSupportFolderPath = @"~/Library/Thunderbird";

@implementation ThunderbirdPreferenceParser

+ (NSString*)pathToSupportFolder {
  return [kThunderbirdSupportFolderPath stringByExpandingTildeInPath];
}

+ (BOOL)thunderbirdIsInstalled {
  NSString* profilesIniPath = [[self pathToSupportFolder] stringByAppendingPathComponent: @"profiles.ini"];
  return [[NSFileManager defaultManager] isReadableFileAtPath: profilesIniPath];
}

+ (NSString*)pathToDefaultProfile {
  NSString* profilesIniPath = [[self pathToSupportFolder] stringByAppendingPathComponent: @"profiles.ini"];
  if(![[NSFileManager defaultManager] isReadableFileAtPath: profilesIniPath])
    return nil;
  
  NSString* profilesIniContents = [NSString stringWithContentsOfFile: profilesIniPath encoding: NSUTF8StringEncoding error: NULL];
  NSScanner* profilesIniScanner = [NSScanner scannerWithString: profilesIniContents];
  NSMutableArray* profiles = [NSMutableArray arrayWithCapacity: 1];   
  
  [profilesIniScanner scanUpToString: @"[Profile" intoString: NULL];
  [profilesIniScanner scanUpToCharactersFromSet: [NSCharacterSet newlineCharacterSet]
                                     intoString: NULL];
  
  if([profilesIniScanner isAtEnd])
    return nil;
  
  do { // for each profile...
    NSString* subString;
    NSMutableDictionary* profile = [NSMutableDictionary dictionaryWithCapacity: 4];
    [profilesIniScanner scanUpToString: @"\n\n"
                            intoString: &subString];
    
    NSScanner* subStringScanner = [NSScanner scannerWithString: subString];
    
    while(![subStringScanner isAtEnd]) { // scan for more attributes
      NSString* key;
      
      // Read in the key and value
      [subStringScanner scanUpToCharactersFromSet: [NSCharacterSet characterSetWithCharactersInString: @"="]
                        
                                       intoString: &key];
      
      [subStringScanner scanCharactersFromSet: [NSCharacterSet characterSetWithCharactersInString: @"="]
                                   intoString: NULL];
      
      // deal with each possible attribute
      if([key isEqual: @"Name"]) {
        NSString* profileName;
        [subStringScanner scanUpToCharactersFromSet: [NSCharacterSet newlineCharacterSet]
                                         intoString: &profileName];
        profile[@"Name"] = profileName;
      }
      else if([key isEqual: @"IsRelative"]) {
        int isRelative = 1;
        [subStringScanner scanInt: &isRelative];
        profile[@"IsRelative"] = @(isRelative);
      }
      else if([key isEqual: @"Default"]) {
        int isDefault = 0;
        [subStringScanner scanInt: &isDefault];
        profile[@"Default"] = @(isDefault);
      }
      else if([key isEqual: @"Path"]) {
        NSString* path;
        [subStringScanner scanUpToCharactersFromSet: [NSCharacterSet newlineCharacterSet]
                                         intoString: &path];
        profile[@"Path"] = path;
      }
    }
    
    [profiles addObject: profile]; // add the profile into the array of profiles
  } while(![profilesIniScanner isAtEnd]);
  
  NSDictionary* defaultProfile = nil;
  
  for(NSUInteger i = 0; i < [profiles count]; i++) {
    NSDictionary* p = profiles[i];
    if([p[@"Default"] isEqual: @1]) {
      defaultProfile = p;
      break;
    }
    if([p[@"Name"] isEqual: @"default"])
      defaultProfile = p;
  }
  
  if(defaultProfile == nil) {
    defaultProfile = profiles[0];
  }
  if(defaultProfile == nil)
    return nil;
  
  NSString* pathToProfile = defaultProfile[@"Path"];
  if(pathToProfile == nil)
    return nil;
  
  if([defaultProfile[@"IsRelative"] isEqual: @0])
    return [pathToProfile stringByStandardizingPath];
  else
    return [[[self pathToSupportFolder] stringByAppendingPathComponent: pathToProfile] stringByStandardizingPath];  
}

+ (NSString*)pathToPrefsJsFile {
  NSString* pathToDefaultProfile = [self pathToDefaultProfile];
  if(pathToDefaultProfile == nil)
    return nil;
  return [pathToDefaultProfile stringByAppendingPathComponent: @"prefs.js"];
}

+ (NSArray*)incomingHostnames {
  NSString* pathToPrefsJsFile = [self pathToPrefsJsFile];
  if(pathToPrefsJsFile == nil)
    return @[];
  if(![[NSFileManager defaultManager] isReadableFileAtPath: pathToPrefsJsFile])
    return @[];
  
  NSArray* prefsJsLines = [[NSString stringWithContentsOfFile: pathToPrefsJsFile encoding: NSUTF8StringEncoding error: NULL] componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
  NSMutableArray* hostnames = [NSMutableArray arrayWithCapacity: 10];
  
  for(NSUInteger i = 0; i < [prefsJsLines count]; i++) {
    NSString* line = prefsJsLines[i];
    // All of the asterisks are necessary for globbing so that any amount of
    // whitespace will work.
    if([line isLike: @"*user_pref(*\"mail.server.server*.hostname\"*,*\"*\"*)*;*"]) {
      NSArray* parts = [line  componentsSeparatedByString: @"\""];
      // If the hostname is "Local Folders", it's a special Thunderbird thing,
      // and obviously not something we can block.
      if([parts count] >= 4 && ![parts[3] isEqual: @"Local Folders"]) {
        [hostnames addObject: [parts[3] stringByAppendingString: @":110"]];
      }
    }
    else if([line isLike: @"*user_pref(*\"mail.server.server*.port\"*,*)*;*"]) {
      NSArray* parts = [line  componentsSeparatedByString: @","];
      parts = [parts[1]  componentsSeparatedByString: @")"];
      int portNumber = [[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] intValue];
      NSString* alteredHost = [hostnames[([hostnames count] - 1)]  componentsSeparatedByString: @":"][0];
      alteredHost = [alteredHost stringByAppendingFormat: @":%d", portNumber];
      hostnames[([hostnames count] - 1)] = alteredHost;
    }
  }
  
  return hostnames;
}

+ (NSArray*)outgoingHostnames {
  NSString* pathToPrefsJsFile = [self pathToPrefsJsFile];
  if(pathToPrefsJsFile == nil)
    return @[];
  if(![[NSFileManager defaultManager] isReadableFileAtPath: pathToPrefsJsFile])
    return @[];
  
  NSArray* prefsJsLines = [[NSString stringWithContentsOfFile: pathToPrefsJsFile encoding: NSUTF8StringEncoding error: NULL]  componentsSeparatedByString: @"\n"];
  NSMutableArray* hostnames = [NSMutableArray arrayWithCapacity: 10];
  
  for(NSUInteger i = 0; i < [prefsJsLines count]; i++) {
    NSString* line = prefsJsLines[i];
    if([line isLike: @"*user_pref(*\"mail.smtpserver.smtp*.hostname\"*,*\"*\"*)*;*"]) {
      NSArray* parts = [line componentsSeparatedByString: @"\""];
      if([parts count] >= 4 && ![parts[3] isEqual: @"Local Folders"]) {
        [hostnames addObject: [parts[3] stringByAppendingString: @":25"]];
      }
    }
    // If there's a port number, add it to the last added hostname.  Yes, it could
    // technically be associated with a different hostname, but only if the user
    // was manually editing the preferences file and changed it stupidly.
    else if([line isLike: @"*user_pref(*\"mail.smtpserver.smtp*.port\"*,*)*;*"]) {
      NSArray* parts = [line  componentsSeparatedByString: @","];
      parts = [parts[1] componentsSeparatedByString: @")"];
      int portNumber = [[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] intValue];
      NSString* alteredHost = [hostnames[([hostnames count] - 1)] componentsSeparatedByString: @":"][0];
      alteredHost = [alteredHost stringByAppendingFormat: @":%d", portNumber];
      hostnames[([hostnames count] - 1)] = alteredHost;
    }
  }
  
  return hostnames;
}

@end
