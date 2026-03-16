//
//  SCScheduleManager.m
//  SelfControl
//
//  Manages recurring scheduled blocks via launchd user agents.
//

#import "SCScheduleManager.h"
#import "SCBlockFileReaderWriter.h"

static NSString *const kScheduledBlocks = @"ScheduledBlocks";

@implementation SCScheduleManager {
    NSUserDefaults *defaults_;
}

+ (instancetype)sharedManager {
    static SCScheduleManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SCScheduleManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        defaults_ = [NSUserDefaults standardUserDefaults];
    }
    return self;
}

#pragma mark - Schedule CRUD

- (NSArray<SCSchedule *> *)allSchedules {
    NSArray *dicts = [defaults_ arrayForKey:kScheduledBlocks];
    if (!dicts) return @[];

    NSMutableArray<SCSchedule *> *schedules = [NSMutableArray arrayWithCapacity:dicts.count];
    for (NSDictionary *dict in dicts) {
        [schedules addObject:[SCSchedule scheduleFromDictionary:dict]];
    }
    return [schedules copy];
}

- (void)saveSchedules:(NSArray<SCSchedule *> *)schedules {
    NSMutableArray *dicts = [NSMutableArray arrayWithCapacity:schedules.count];
    for (SCSchedule *s in schedules) {
        [dicts addObject:[s dictionaryRepresentation]];
    }
    [defaults_ setObject:dicts forKey:kScheduledBlocks];
    [defaults_ synchronize];
}

- (void)addSchedule:(SCSchedule *)schedule {
    NSMutableArray<SCSchedule *> *schedules = [[self allSchedules] mutableCopy];
    [schedules addObject:schedule];
    [self saveSchedules:schedules];
}

- (void)removeSchedule:(SCSchedule *)schedule {
    NSMutableArray<SCSchedule *> *schedules = [[self allSchedules] mutableCopy];
    NSUInteger idx = NSNotFound;
    for (NSUInteger i = 0; i < schedules.count; i++) {
        if ([schedules[i].identifier isEqualToString:schedule.identifier]) {
            idx = i;
            break;
        }
    }
    if (idx != NSNotFound) {
        [schedules removeObjectAtIndex:idx];
    }
    [self saveSchedules:schedules];
}

- (void)updateSchedule:(SCSchedule *)schedule {
    NSMutableArray<SCSchedule *> *schedules = [[self allSchedules] mutableCopy];
    for (NSUInteger i = 0; i < schedules.count; i++) {
        if ([schedules[i].identifier isEqualToString:schedule.identifier]) {
            schedules[i] = schedule;
            break;
        }
    }
    [self saveSchedules:schedules];
}

#pragma mark - Launchd Agent Sync

- (void)syncAllLaunchdAgents {
    NSArray<SCSchedule *> *schedules = [self allSchedules];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *launchAgentsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    NSString *schedulesDir = [self schedulesDirectory];

    // Ensure directories exist
    [fm createDirectoryAtPath:launchAgentsDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:schedulesDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Collect labels of all current schedules
    NSMutableSet<NSString *> *activeLabels = [NSMutableSet set];
    for (SCSchedule *schedule in schedules) {
        [activeLabels addObject:[schedule launchdLabel]];
    }

    // Remove stale plist files (schedules that were removed or disabled)
    NSArray *existingPlists = [fm contentsOfDirectoryAtPath:launchAgentsDir error:nil];
    for (NSString *filename in existingPlists) {
        if ([filename hasPrefix:@"org.eyebeam.SelfControl.schedule."] && [filename hasSuffix:@".plist"]) {
            NSString *label = [filename stringByDeletingPathExtension];
            BOOL shouldExist = NO;
            for (SCSchedule *schedule in schedules) {
                if (schedule.enabled && [[schedule launchdLabel] isEqualToString:label]) {
                    shouldExist = YES;
                    break;
                }
            }
            if (!shouldExist) {
                NSString *plistPath = [launchAgentsDir stringByAppendingPathComponent:filename];
                [self unloadLaunchdPlist:plistPath];
                [fm removeItemAtPath:plistPath error:nil];
                // Also remove the blocklist file if it exists
                NSString *blocklistLabel = [label stringByReplacingOccurrencesOfString:@"org.eyebeam.SelfControl.schedule." withString:@""];
                NSString *blocklistPath = [schedulesDir stringByAppendingPathComponent:
                                           [NSString stringWithFormat:@"%@.selfcontrol", blocklistLabel]];
                [fm removeItemAtPath:blocklistPath error:nil];
            }
        }
    }

    // Write plists for all enabled schedules
    for (SCSchedule *schedule in schedules) {
        if (!schedule.enabled) continue;

        // Write blocklist file
        NSString *blocklistPath = [schedulesDir stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"%@.selfcontrol", schedule.identifier]];
        NSURL *blocklistURL = [NSURL fileURLWithPath:blocklistPath];
        NSError *writeErr = nil;
        [SCBlockFileReaderWriter writeBlocklistToFileURL:blocklistURL
                                              blockInfo:@{
                                                  @"Blocklist": schedule.blocklist ?: @[],
                                                  @"BlockAsWhitelist": @NO
                                              }
                                                  error:&writeErr];
        if (writeErr) {
            NSLog(@"SCScheduleManager: Failed to write blocklist for schedule %@: %@", schedule.identifier, writeErr);
            continue;
        }

        // Build the launchd plist
        NSDictionary *plist = [self launchdPlistForSchedule:schedule blocklistPath:blocklistPath];
        NSString *plistPath = [launchAgentsDir stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"%@.plist", [schedule launchdLabel]]];

        // Unload existing before overwriting
        if ([fm fileExistsAtPath:plistPath]) {
            [self unloadLaunchdPlist:plistPath];
        }

        // Write and load
        [plist writeToFile:plistPath atomically:YES];
        [self loadLaunchdPlist:plistPath];
    }
}

- (NSDictionary *)launchdPlistForSchedule:(SCSchedule *)schedule blocklistPath:(NSString *)blocklistPath {
    // Path to selfcontrol-cli: bundled inside the app at Contents/MacOS/selfcontrol-cli
    NSString *cliPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"selfcontrol-cli"];
    if (!cliPath) {
        // Fallback: assume standard install location
        cliPath = @"/Applications/SelfControl.app/Contents/MacOS/selfcontrol-cli";
    }

    NSArray *programArguments = @[
        cliPath,
        @"start",
        @"--duration",
        [NSString stringWithFormat:@"%ld", (long)schedule.durationMinutes],
        @"--blocklist",
        blocklistPath
    ];

    // Build StartCalendarInterval: one entry per weekday
    NSMutableArray *calendarIntervals = [NSMutableArray array];
    for (NSNumber *weekday in schedule.weekdays) {
        // launchd uses 0=Sunday through 6=Saturday (same as our model, but launchd
        // uses 7 for Sunday as well; we'll use 0 which is also valid)
        [calendarIntervals addObject:@{
            @"Weekday": weekday,
            @"Hour": @(schedule.hour),
            @"Minute": @(schedule.minute)
        }];
    }

    // If no weekdays specified (daily), use a single entry with just Hour/Minute
    if (calendarIntervals.count == 0) {
        [calendarIntervals addObject:@{
            @"Hour": @(schedule.hour),
            @"Minute": @(schedule.minute)
        }];
    }

    return @{
        @"Label": [schedule launchdLabel],
        @"ProgramArguments": programArguments,
        @"StartCalendarInterval": calendarIntervals,
        @"RunAtLoad": @NO
    };
}

- (NSString *)schedulesDirectory {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    return [appSupport stringByAppendingPathComponent:@"SelfControl/Schedules"];
}

#pragma mark - Launchctl Helpers

- (void)loadLaunchdPlist:(NSString *)path {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments = @[@"load", @"-w", path];
    [task launch];
    [task waitUntilExit];
    if (task.terminationStatus != 0) {
        NSLog(@"SCScheduleManager: launchctl load failed for %@ (status %d)", path, task.terminationStatus);
    }
}

- (void)unloadLaunchdPlist:(NSString *)path {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments = @[@"unload", @"-w", path];
    [task launch];
    [task waitUntilExit];
    // Don't log errors here - the job may already be unloaded
}

@end
