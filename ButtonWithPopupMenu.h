//
//  SCButtonWithPopupMenu.h
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

#import <Cocoa/Cocoa.h>

// A subclass of NSButton that pops up a menu of different choices when clicked.
@interface ButtonWithPopupMenu : NSButton {
	IBOutlet id popUpMenu_; // Manually created (strong)
	NSPopUpButtonCell* popUpCell_;
}

// Sent to this object when the button is clicked.  Pops up the menu.
- (void)mouseDown:(NSEvent*)theEvent;

// Sent to this object when the popup menu is closed.  Un-highlights the button.
- (void)menuClosed:(NSNotification*)note;

@end
