//
//  WhitelistScraper.m
//  SelfControl
//
//  Created by Charles Stigler on 10/7/14.
//
//

#import "WhitelistScraper.h"

@implementation WhitelistScraper

+ (NSSet*)relatedDomains:(NSString*)domain; {
	NSURL* rootURL = [NSURL URLWithString: [NSString stringWithFormat: @"http://%@", domain]];
	if (!rootURL) {
		return nil;;
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

	NSDataDetector* dataDetector = [[NSDataDetector alloc] initWithTypes: NSTextCheckingTypeLink error: nil];
	NSCountedSet* relatedDomains = [NSCountedSet set];
	[dataDetector enumerateMatchesInString: html
								   options: kNilOptions
									 range: NSMakeRange(0, [html length])
								usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
									if (([result.URL.scheme isEqualToString: @"http"] || [result.URL.scheme isEqualToString: @"https"])
										&& [result.URL.host length]
										&& ![result.URL.host isEqualToString: rootURL.host]) {
										[relatedDomains addObject: result.URL.host];
									}
								}];

	return relatedDomains;
}

@end
