//
//  PacketFilter.h
//  SelfControl
//
//  Created by Charles Stigler on 6/29/14.
//
//

#import <Foundation/Foundation.h>

@class SCBlockEntry;

@interface PacketFilter : NSObject {
	NSMutableString* rules;
	BOOL isAllowlist;
}

+ (BOOL)blockFoundInPF;

- (PacketFilter*)initAsAllowlist: (BOOL)allowlist;
- (void)addBlockHeader:(NSMutableString*)configText;
- (void)addAllowlistFooter:(NSMutableString*)configText;
- (void)addRuleWithIP:(NSString*)ip port:(NSInteger)port maskLen:(NSInteger)maskLen;
- (void)writeConfiguration;
- (int)startBlock;
- (int)stopBlock:(BOOL)force;
- (void)addSelfControlConfig;
- (BOOL)containsSelfControlBlock;
- (void)enterAppendMode;
- (void)finishAppending;
- (int)refreshPFRules;

@end
