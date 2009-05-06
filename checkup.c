/*
 *  checkup.c
 *  SelfControl
 *
 *  Created by Charlie Stigler on 5/3/09.
 *  Copyright 2009 Harvard-Westlake Student. All rights reserved.
 *
 */

#include "checkup.h"

int main(int argc, char* argv[]) {
  if(geteuid()) {
    printf("ERROR: checkup must be run as root.\n");
    exit(EXIT_FAILURE);
  }

  char* args[] = { "launchctl", "start", "org.eyebeam.SelfControl", NULL };
  
  return execve("/bin/launchctl", args, NULL); 
}
