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
@property (readonly) NSInteger durationValueMinutes;
@property (readonly) NSString* durationDescription;

- (NSInteger)durationValueMinutes;
- (void)bindDurationToObject:(id)obj keyPath:(NSString*)keyPath;
- (NSString*)durationDescription;

+ (NSString *)timeSliderDisplayStringFromTimeInterval:(NSTimeInterval)numberOfSeconds;
+ (NSString *)timeSliderDisplayStringFromNumberOfMinutes:(NSInteger)numberOfMinutes;

@end

NS_ASSUME_NONNULL_END
