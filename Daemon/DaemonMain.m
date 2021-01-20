//
//  DaemonMain.m
//  SelfControl
//
//  Created by Charlie Stigler on 5/28/20.
//

#import <Foundation/Foundation.h>
#import "SCDaemon.h"

// Entry point for the SelfControl daemon process (selfcontrold)
int main(int argc, const char *argv[]) {
    [SCSentry startSentry: @"org.eyebeam.selfcontrold"];

    // get the daemon object going
    SCDaemon* daemon = [SCDaemon sharedDaemon];
    [daemon start];
        
    NSLog(@"running forever");
    
    // never gonna give you up, never gonna let you down, never gonna run around and desert you...
    [[NSRunLoop currentRunLoop] run];

    return 0;
}
