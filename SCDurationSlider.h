//
//  SCTimeSlider.h
//  SelfControl
//
//  Created by Charlie Stigler on 4/17/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCDurationSlider : NSSlider

@property (nonatomic, assign) NSInteger maxDuration;
@property (nonatomic, assign) NSInteger durationTickInterval;
@property (readonly) NSInteger durationValueMinutes;
@property (readonly) NSString* durationDescription;

- (NSInteger)durationValueMinutes;
- (void)bindDurationToObject:(id)obj keyPath:(NSString*)keyPath;
- (NSString*)durationDescription;

@end

NS_ASSUME_NONNULL_END
