/*
 
 File:			GPSSatInfo.m
 Program:		KisMAC
 Author:	    Geordie  themacuser -at- gmail.com
 Description:	KisMAC is a wireless stumbler for MacOS X.
 
 This file is part of KisMAC.
 
 KisMAC is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 KisMAC is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with KisMAC; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "GPSSatInfo.h"


@implementation GPSSatInfo

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByWordWrapping];
        [style setAlignment:NSCenterTextAlignment];
        attr = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, [NSColor greenColor], NSForegroundColorAttributeName, nil];
        [style release];
    }
    return self;

	
}

- (void)drawRect:(NSRect)rect {
	NSRect r;
	NSBezierPath *bp;
	NSColor *color;
	int currentsat,strength,prn;
	bool used;

	bp = [NSBezierPath bezierPathWithRect:[self bounds]];
	[[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:0.7] set];
	[bp fill];
	
	for (currentsat = 1; currentsat <= 12; currentsat++) {
		strength = [self getSignalForSat:currentsat];
		prn = [self getPRNForSat:currentsat];
		used = [self getUsedForSat:currentsat];
		
		r = NSMakeRect((((currentsat - 1) * 18) + 11), 12, 16, ((strength + 1) * 1.5));
		bp = [NSBezierPath bezierPathWithRect:r];
		
		if (used) {
			color = [NSColor greenColor];
		} else {
			color = [NSColor redColor];
		}
		
		if (prn > 0 && prn < 10) {
		[[NSString stringWithFormat:@"%i",prn] drawAtPoint:NSMakePoint((((currentsat - 1) * 18) + 14),-2) withAttributes:attr];
		}
		
		if (prn >= 10) {
		[[NSString stringWithFormat:@"%i",prn] drawAtPoint:NSMakePoint((((currentsat - 1) * 18) + 11),-2) withAttributes:attr];
		}
		
		[color set];
		[bp fill];

	}
}

- (int)getPRNForSat:(int)sat {
	if (sat == 1) {
		return sat1_prn;
	} else if (sat == 2) {
		return sat2_prn;
	} else if (sat == 3) {
		return sat3_prn;
	} else if (sat == 4) {
		return sat4_prn;
	} else if (sat == 5) {
		return sat5_prn;
	} else if (sat == 6) {
		return sat6_prn;
	} else if (sat == 7) {
		return sat7_prn;
	} else if (sat == 8) {
		return sat8_prn;
	} else if (sat == 9) {
		return sat9_prn;
	} else if (sat == 10) {
		return sat10_prn;
	} else if (sat == 11) {
		return sat11_prn;
	} else if (sat == 12) {
		return sat12_prn;
	} else {
		return 0;
	}
}

- (void)setPRNForSat:(int)sat PRN:(int)prn {
	if (sat == 1) {
		 sat1_prn = prn;
	} else if (sat == 2) {
		 sat2_prn = prn;
	} else if (sat == 3) {
		 sat3_prn = prn;
	} else if (sat == 4) {
		 sat4_prn = prn;
	} else if (sat == 5) {
		 sat5_prn = prn;
	} else if (sat == 6) {
		 sat6_prn = prn;
	} else if (sat == 7) {
		 sat7_prn = prn;
	} else if (sat == 8) {
		 sat8_prn = prn;
	} else if (sat == 9) {
		 sat9_prn = prn;
	} else if (sat == 10) {
		 sat10_prn = prn;
	} else if (sat == 11) {
		 sat11_prn = prn;
	} else if (sat == 12) {
		 sat12_prn = prn;
	}
}

- (int)getUsedForSat:(int)sat {
	if (sat == 1) {
		return sat1_used;
	} else if (sat == 2) {
		return sat2_used;
	} else if (sat == 3) {
		return sat3_used;
	} else if (sat == 4) {
		return sat4_used;
	} else if (sat == 5) {
		return sat5_used;
	} else if (sat == 6) {
		return sat6_used;
	} else if (sat == 7) {
		return sat7_used;
	} else if (sat == 8) {
		return sat8_used;
	} else if (sat == 9) {
		return sat9_used;
	} else if (sat == 10) {
		return sat10_used;
	} else if (sat == 11) {
		return sat11_used;
	} else if (sat == 12) {
		return sat12_used;
	}
}

- (void)setUsedForSat:(int)sat used:(int)used {
	if (sat == 1) {
		 sat1_used = used;
	} else if (sat == 2) {
		 sat2_used = used;
	} else if (sat == 3) {
		 sat3_used = used;
	} else if (sat == 4) {
		 sat4_used = used;
	} else if (sat == 5) {
		 sat5_used = used;
	} else if (sat == 6) {
		 sat6_used = used;
	} else if (sat == 7) {
		 sat7_used = used;
	} else if (sat == 8) {
		 sat8_used = used;
	} else if (sat == 9) {
		 sat9_used = used;
	} else if (sat == 10) {
		 sat10_used = used;
	} else if (sat == 11) {
		 sat11_used = used;
	} else if (sat == 12) {
		 sat12_used = used;
	}
}


- (int)getSignalForSat:(int)sat {
	if (sat == 1) {
		return sat1_strength;
	} else if (sat == 2) {
		return sat2_strength;
	} else if (sat == 3) {
		return sat3_strength;
	} else if (sat == 4) {
		return sat4_strength;
	} else if (sat == 5) {
		return sat5_strength;
	} else if (sat == 6) {
		return sat6_strength;
	} else if (sat == 7) {
		return sat7_strength;
	} else if (sat == 8) {
		return sat8_strength;
	} else if (sat == 9) {
		return sat9_strength;
	} else if (sat == 10) {
		return sat10_strength;
	} else if (sat == 11) {
		return sat11_strength;
	} else if (sat == 12) {
		return sat12_strength;
	}
}

- (int)setSignalForSat:(int)sat signal:(int)signal {
	if (sat == 1) {
		sat1_strength = signal;
	} else if (sat == 2) {
		sat2_strength = signal;
	} else if (sat == 3) {
		sat3_strength = signal;
	} else if (sat == 4) {
		sat4_strength = signal;
	} else if (sat == 5) {
		sat5_strength = signal;
	} else if (sat == 6) {
		sat6_strength = signal;
	} else if (sat == 7) {
		sat7_strength = signal;
	} else if (sat == 8) {
		sat8_strength = signal;
	} else if (sat == 9) {
		sat9_strength = signal;
	} else if (sat == 10) {
		sat10_strength = signal;
	} else if (sat == 11) {
		sat11_strength = signal;
	} else if (sat == 12) {
		sat12_strength = signal;
	}
}

- (void)redraw {
	[self lockFocus];
	[self setNeedsDisplay:YES];
	[self unlockFocus];
}

@end
