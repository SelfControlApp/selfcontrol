//
//  checkup.c
//  SelfControl
//
//  Created by Charlie Stigler on 5/03/09.
//  Copyright 2009 Eyebeam. 

// This file is part of SelfControl.
// 
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include "checkup.h"

int main(int argc, char* argv[]) {
  if(geteuid()) {
    printf("ERROR: checkup must be run with root privileges.\n");
    exit(EXIT_FAILURE);
  }

  char* args[] = { "launchctl", "start", "org.eyebeam.SelfControl", NULL };
  
  return execve("/bin/launchctl", args, NULL); 
}
