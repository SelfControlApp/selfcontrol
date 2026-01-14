//
//  AllowlistScraper.m
//  SelfControl
//
//  Created by Charles Stigler on 10/7/14.
//
//

#import "AllowlistScraper.h"
#import "SCBlockEntry.h"

@implementation AllowlistScraper

+ (NSSet<SCBlockEntry*>*)relatedBlockEntries:(NSString*)domain; {
	NSURL* rootURL = [NSURL URLWithString: [NSString stringWithFormat: @"http://%@", domain]];
	if (!rootURL) {
		return nil;
	}

	// stale data is OK
	NSURLRequest* request = [NSURLRequest requestWithURL: rootURL cachePolicy: NSURLRequestReturnCacheDataElseLoad timeoutInterval: 5];
	NSURLResponse* response = nil;
	NSError* error = nil;
	NSData* data = [NSURLConnection sendSynchronousRequest: request returningResponse: &response error: &error];
	if (!response) {
		return nil;
	}
	NSString* html = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	if (!html) {
		return nil;
	}

    // these sites are often featured in "share links" on a wide variety of websites
    // we really don't want to add them to the allowlist, since they're also
    // super distracting. So explicitly flag them to skip in this process
    NSArray* neverAddSites = @[
        @"instagram.com",
        @"www.instagram.com",
        @"twitter.com",
        @"www.twitter.com",
        @"facebook.com",
        @"www.facebook.com",
        @"reddit.com",
        @"www.reddit.com",
        @"youtube.com",
        @"www.youtube.com",
        @"pinterest.com",
        @"plus.google.com",
        @"www.pinterest.com",
        @"linkedin.com",
        @"www.linkedin.com",
        @"tumblr.com",
        @"www.tumblr.com"
    ];

	NSDataDetector* dataDetector = [[NSDataDetector alloc] initWithTypes: NSTextCheckingTypeLink error: nil];
	NSCountedSet<SCBlockEntry*>* relatedEntries = [NSCountedSet set];
	[dataDetector enumerateMatchesInString: html
								   options: kNilOptions
									 range: NSMakeRange(0, [html length])
								usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
									if (([result.URL.scheme isEqualToString: @"http"] || [result.URL.scheme isEqualToString: @"https"])
										&& [result.URL.host length]
										&& ![result.URL.host isEqualToString: rootURL.host]
                                        && ![neverAddSites containsObject: result.URL.host]) {
                                        [relatedEntries addObject: [SCBlockEntry entryWithHostname: result.URL.host]];
                                    }
								}];

	return relatedEntries;
}

@end
