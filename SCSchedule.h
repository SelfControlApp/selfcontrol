//
//  SCSchedule.h
//  SelfControl
//
//  Model for a recurring scheduled block.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCSchedule : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray<NSNumber *> *weekdays; // 0=Sun through 6=Sat
@property (nonatomic, assign) NSInteger hour;
@property (nonatomic, assign) NSInteger minute;
@property (nonatomic, assign) NSInteger durationMinutes;
@property (nonatomic, copy) NSArray<NSString *> *blocklist;
@property (nonatomic, assign) BOOL enabled;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)scheduleFromDictionary:(NSDictionary *)dict;

// Returns the launchd label for this schedule, e.g. org.eyebeam.SelfControl.schedule.<identifier>
- (NSString *)launchdLabel;

@end

NS_ASSUME_NONNULL_END
