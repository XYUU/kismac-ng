/*
        
        File:			TraceView.m
        Program:		KisMAC
	Author:			Michael Roßberg
				mick@binaervarianz.de
	Description:		KisMAC is a wireless stumbler for MacOS X.
                
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

#import "TraceView.h"
#import "GPSController.h"
#import "WaveHelper.h"
#import "ZoomPictureView.h"

@implementation TraceView

- (void)drawRect:(NSRect)rect {
    NSArray *t;
    ZoomPictureView *z;
    NSBezierPath *b;
    NSPoint p;
    int i, c;
    
    if ([self lockFocusIfCanDraw]) {
        t = [[WaveHelper gpsController] traceArray];
        if ([t count] >= 4) {
            z = [WaveHelper zoomPictureView];
            c = [t count] / 2;
            
            [z calcPixelforNS:[[t objectAtIndex:0] doubleValue] EW:[[t objectAtIndex:1] doubleValue] forPoint:&p];
            b = [NSBezierPath bezierPath];
            [b moveToPoint:p];

            for (i=1;i<c;i++) {
                [z calcPixelforNS:[[t objectAtIndex:2*i] doubleValue] EW:[[t objectAtIndex:2*i+1] doubleValue] forPoint:&p];
                [b lineToPoint:p];
            }
            [[WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"TraceColor"]] set];
            [b setLineWidth:2];
            [b stroke];
        }
        [self unlockFocus]; 
    }
}

@end
