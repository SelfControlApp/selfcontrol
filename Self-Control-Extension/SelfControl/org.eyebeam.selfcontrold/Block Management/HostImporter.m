//
//  HostImporter.m
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


#import "HostImporter.h"

@implementation HostImporter

+ (NSArray*)commonDistractingWebsites {
	return @[
			 @"facebook.com",
			 @"twitter.com",
			 @"reddit.com",
			 @"tumblr.com",
			 @"youtube.com",
			 @"9gag.com",
			 @"netflix.com",
			 @"hulu.com",
			 @"buzzfeed.com",
			 @"dailymotion.com",
			 @"collegehumor.com",
			 @"funnyordie.com",
			 @"vine.co",
			 @"pinterest.com",
			 @"stumbleupon.com",
                       @"instagram.com",
			 ];
}
+ (NSArray*)newsAndPublications {
	return @[
			 @"cnn.com",
			 @"huffingtonpost.com",
			 @"foxnews.com",
			 @"nytimes.com",
			 @"bbc.com",
			 @"bbc.co.uk",
			 @"telegraph.co.uk",
			 @"news.google.com",
			 @"buzzfeed.com",
			 @"vice.com",
			 @"gawker.com",
			 @"tumblr.com",
			 @"forbes.com",
			 @"gothamist.com",
			 @"jezebel.com",
			 @"usatoday.com",
			 @"theonion.com",
			 @"news.yahoo.com",
			 @"washingtonpost.com",
			 @"wsj.com",
			 @"theguardian.com",
			 @"latimes.com",
			 @"nydailynews.com",
			 @"salon.com",
			 @"msnbc.com",
			 @"rt.com",
			 @"bloomberg.com",
			 @"aol.com",
			 @"drudgereport.com",
			 @"nationalgeographic.com",
			 @"vice.com",
			 @"nypost.com",
			 @"chicagotribune.com",
			 @"msn.com",
			 @"usnews.com",
			 ];
}

+ (NSArray*)incomingMailHostnamesFromMail {
	NSMutableArray* hostnames = [NSMutableArray arrayWithCapacity: 10];
	NSString* sandboxedPreferences = [@"~/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail" stringByExpandingTildeInPath];
	NSDictionary* defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName: sandboxedPreferences];
	NSArray* incomingAccounts = defaults[@"MailAccounts"];
	for(NSUInteger i = 0; i < [incomingAccounts count]; i++) {
		NSMutableString* hostname = [incomingAccounts[i][@"Hostname"] mutableCopy];
		// The LocalAccountName account has no hostname, so trying to add it would cause an error
		if(hostname != nil) {
			// If it has a defined port number, add it to the host to block for added
			// block specificity, so only incoming mail is blocked.
			if([incomingAccounts[i][@"PortNumber"] length]) {
				[hostname appendString: @":"];
				[hostname appendString: incomingAccounts[i][@"PortNumber"]];
				// If it doesn't have a defined port number, we'll go through and choose
				// the default port for the type of account it is.
			} else if([incomingAccounts[i][@"AccountType"] isEqual: @"POPAccount"]) {
				if(incomingAccounts[i][@"SSLEnabled"]) {
					[hostname appendString: @":995"];
				} else {
					[hostname appendString: @":110"];
				}
			} else if([incomingAccounts[i][@"AccountType"] isEqual: @"IMAPAccount"]) {
				if(incomingAccounts[i][@"SSLEnabled"]) {
					[hostname appendString: @":993"];
				} else {
					[hostname appendString: @":143"];
				}
			}
			[hostnames addObject: hostname];
		}
	}

	return hostnames;
}

+ (NSArray*)outgoingMailHostnamesFromMail {
	NSMutableArray* hostnames = [NSMutableArray arrayWithCapacity: 10];
	NSString* sandboxedPreferences = [@"~/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail" stringByExpandingTildeInPath];
	NSDictionary* defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName: sandboxedPreferences];
	NSArray* outgoingAccounts = defaults[@"DeliveryAccounts"];
	for(NSUInteger i = 0; i < [outgoingAccounts count]; i++) {
		NSMutableString* hostname = [outgoingAccounts[i][@"Hostname"] mutableCopy];
		if(hostname != nil) {
			if([outgoingAccounts[i][@"PortNumber"] length]) {
				[hostname appendString: @":"];
				[hostname appendString: outgoingAccounts[i][@"PortNumber"]];
			} else if (outgoingAccounts[i][@"SSLEnabled"]) {
				// If it doesn't have a defined port number, we'll block all the default outoging ports
				[hostnames addObject: [hostname stringByAppendingString: @":465"]];
				[hostname appendString: @":587"];
			} else {
				[hostname appendString: @":25"];
			}

			[hostnames addObject: hostname];
		}
	}

	return hostnames;
}

+ (NSArray*)incomingMailHostnamesFromMailMate {
	NSMutableArray* hostnames = [NSMutableArray arrayWithCapacity: 10];

	NSString* sourcesPath = [@"~/Library/Application Support/MailMate/Sources.plist" stringByExpandingTildeInPath];
	NSData* plistData = [NSData dataWithContentsOfFile: sourcesPath];
	if (!plistData) return hostnames;

	NSDictionary* prefs = [NSPropertyListSerialization propertyListWithData: plistData options: NSPropertyListImmutable format: nil error: nil];
	if (!prefs) return hostnames;

	NSArray* accounts = prefs[@"sources"];
	for(NSUInteger i = 0; i < [accounts count]; i++) {
		NSURL* serverURL = [NSURL URLWithString: accounts[i][@"serverURL"]];
		if (!serverURL) continue;

		NSMutableString* hostname = [serverURL.host mutableCopy];
		if (![hostname length]) continue;

		// If it has a defined port number, add it to the host to block for added
		// block specificity, so only incoming mail is blocked.
		if([accounts[i][@"port"] length]) {
			[hostname appendString: @":"];
			[hostname appendString: accounts[i][@"port"]];
		} else if([serverURL.scheme isEqualToString: @"imap"]) {
			[hostname appendString: @":993"];
			[hostnames addObject: [hostname stringByAppendingString: @":143"]];
		} else if([serverURL.scheme isEqualToString: @"pop"]) {
			[hostname appendString: @":995"];
			[hostnames addObject: [hostname stringByAppendingString: @":110"]];
		}

		[hostnames addObject: hostname];
	}

	return hostnames;
}
+ (NSArray*)outgoingMailHostnamesFromMailMate {
	NSMutableArray* hostnames = [NSMutableArray arrayWithCapacity: 10];

	NSString* submissionPath = [@"~/Library/Application Support/MailMate/Submission.plist" stringByExpandingTildeInPath];
	NSData* plistData = [NSData dataWithContentsOfFile: submissionPath];
	if (!plistData) return hostnames;

	NSDictionary* prefs = [NSPropertyListSerialization propertyListWithData: plistData options: NSPropertyListImmutable format: nil error: nil];
	if (!prefs) return hostnames;

	NSArray* smtpServers = prefs[@"smtpServers"];
	for(NSUInteger i = 0; i < [smtpServers count]; i++) {
		NSURL* serverURL = [NSURL URLWithString: smtpServers[i][@"serverURL"]];
		if (!serverURL) continue;

		NSMutableString* hostname = [serverURL.host mutableCopy];
		if (![hostname length]) continue;

		// If it has a defined port number, add it to the host to block for added
		// block specificity, so only incoming mail is blocked.
		if([smtpServers[i][@"port"] length]) {
			[hostname appendString: @":"];
			[hostname appendString: smtpServers[i][@"port"]];
		} else {
			[hostname appendString: @":25"];
			[hostnames addObject: [hostname stringByAppendingString: @":587"]];
		}

		[hostnames addObject: hostname];
	}

	return hostnames;
}


+ (NSArray*)incomingMailHostnamesFromThunderbird {
	return [ThunderbirdPreferenceParser incomingHostnames];
}

+ (NSArray*)outgoingMailHostnamesFromThunderbird {
	return [ThunderbirdPreferenceParser outgoingHostnames];
}

@end
