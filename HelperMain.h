//
//  HelperMain.h
//  SelfControl
//
//  Created by Charlie Stigler on 2/4/09.
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

// The main class for SelfControl's helper tool to be run by launchd with high
// privileges in order to handle the root-only configuration.

#import "PacketFilter.h"
#import "HelperCommon.h"

// The main method which deals which most of the logic flow and execution of
// the helper tool.  Posts an SCConfigurationChangedNotification if the block
// is enabled or disabled.
int main(int argc, char* argv[]);
