//
//  SCButtonWithPopupMenu.m
//  SelfControl
//
//  Created by Charlie Stigler on 2/18/09.
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

// Thanks to Jim McGowan for this implementation.  For his source, see:
// http://www.jimmcgowan.net/Site/Blog/Entries/2007/8/27_Adding_a_Menu_to_an_NSButton.html

#import "ButtonWithPopupMenu.h"

@implementation ButtonWithPopupMenu

- (void)awakeFromNib {
	popUpCell_ = [[NSPopUpButtonCell alloc] initTextCell: @"" pullsDown: YES];

	[popUpCell_ setMenu: popUpMenu_];

	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(menuClosed:)
												 name: NSMenuDidEndTrackingNotification
											   object: popUpMenu_];
}

- (void)mouseDown:(NSEvent*)theEvent {
	[self highlight: YES];
	[popUpCell_ performClickWithFrame: [self bounds] inView: self];
}

- (void)menuClosed:(NSNotification*)note {
	[self highlight: NO];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: NSMenuDidEndTrackingNotification
												  object: popUpMenu_];
}


@end