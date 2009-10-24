//
//  checkup.h
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

// This (and checkup.c) are a standalone helper binary that just start the 
// org.eyebeam.SelfControl launchd task immediately if it's already loaded.
// The purpose of this is that the standalone binary can be given the suid bit
// with no negative security effects, and be used to do checkups at times when
// one is needed without the user typing a password.  Currently the helper program
// is not in use and is not distributed.

#include <unistd.h>

int main(int argc, char* argv[]);
