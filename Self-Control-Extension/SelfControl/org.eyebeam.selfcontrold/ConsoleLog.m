//
//  ConsoleLog.m
//  SelfControl
//
//  Created by Satendra Singh on 25/12/25.
//

#import "ConsoleLog.h"
#include <os/log.h>

@implementation ConsoleLog

+ (void)log:(NSString *)message {
    os_log(OS_LOG_DEFAULT, "ConsoleLog: [SC] 🔍] %{public}@", message);
}

@end
