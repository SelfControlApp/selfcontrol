//
//  SCScheduleManager.h
//  SelfControl
//
//  Manages recurring scheduled blocks via launchd user agents.
//

#import <Foundation/Foundation.h>
#import "SCSchedule.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCScheduleManager : NSObject

+ (instancetype)sharedManager;

- (NSArray<SCSchedule *> *)allSchedules;
- (void)addSchedule:(SCSchedule *)schedule;
- (void)removeSchedule:(SCSchedule *)schedule;
- (void)updateSchedule:(SCSchedule *)schedule;

// Writes/removes launchd plists for all schedules and loads/unloads as needed.
- (void)syncAllLaunchdAgents;

@end

NS_ASSUME_NONNULL_END
