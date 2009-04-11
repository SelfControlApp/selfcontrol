//
//  NSCharacterSet+NewlineAddition.h
//  SelfControl
//
//  Created by Charlie Stigler on 4/2/09.
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

#import <Cocoa/Cocoa.h>

// A category to add a +newlineCharacterSet convenience method to the NSCharacterSet
// class, because 10.4 Tiger and below are missing the method.
@interface NSCharacterSet (NewlineAddition)

// Returns a set of all possible characters that could distinguish a newline.
// This implementation was taken from the Skim PDF Reader and Note-taker for OS X,
// a SourceForge project under the BSD License.  The project can be found at
// http://sourceforge.net/projects/skim-app.  This implementation will override
// the real method on Leopard, but it shouldn't matter too much.
+ (NSCharacterSet*)newlineCharacterSet;

@end
