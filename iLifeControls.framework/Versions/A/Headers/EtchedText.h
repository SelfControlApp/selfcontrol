/* EtchedText */

#import <Cocoa/Cocoa.h>

@interface EtchedText : NSTextField
{
}
+ (Class)cellClass;

-(void)setShadowColor:(NSColor *)color;

@end
