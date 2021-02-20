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

    NSDate* startedScraping  = [NSDate date];
	NSDataDetector* dataDetector = [[NSDataDetector alloc] initWithTypes: NSTextCheckingTypeLink error: nil];
	NSCountedSet<SCBlockEntry*>* relatedEntries = [NSCountedSet set];
	[dataDetector enumerateMatchesInString: html
								   options: kNilOptions
									 range: NSMakeRange(0, [html length])
								usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
									if (([result.URL.scheme isEqualToString: @"http"] || [result.URL.scheme isEqualToString: @"https"])
										&& [result.URL.host length]
										&& ![result.URL.host isEqualToString: rootURL.host]) {
                                        [relatedEntries addObject: [SCBlockEntry entryWithHostname: result.URL.host]];
                                    }
								}];
    NSDate* finishedScraping  = [NSDate date];
    NSTimeInterval resolutionTime = [finishedScraping timeIntervalSinceDate: startedScraping];
    if (resolutionTime > 5.0) {
        NSLog(@"BlockManager: Warning: related block entries took %f seconds to enumerate %d entries for %@", resolutionTime, relatedEntries.count, domain);
    }

	return relatedEntries;
}

@end
