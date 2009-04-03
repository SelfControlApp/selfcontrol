/* MyTitleCell */

#import <Cocoa/Cocoa.h>

@interface EtchedTextCell : NSTextFieldCell
{
	NSColor *mShadowColor;
}

-(void)setShadowColor:(NSColor *)color;

@end
