/*
        
        File:			MapControlPanel.m
        Program:		KisMAC
		Author:			Michael Roßberg
						mick@binaervarianz.de
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

#import "MapControlPanel.h"
#import "WaveHelper.h"
#import "MapView.h"
#import "MapControlItem.h"

#define CONTROLSIZE 30.0
#define CURVERAD 5.0
#define BORDER 1.0
#define OFFSET (CURVERAD + BORDER)
#define TRIANGLESIZE 15.0

@implementation MapControlPanel

- (id)init {
    int i, x, y;
    self = [super init];
    if (!self) return nil;
    
	[self setSize:NSMakeSize(3 * CONTROLSIZE, 2 * CONTROLSIZE)];
	for (x=0; x<3; x++) {
        for (y=0; y<2; y++) {
			i = (x + (y * 3));
			_items[i] = [[MapControlItem alloc] initForID:i];
			[self addSubView:_items[i]];
			[_items[i] setLocation:NSMakePoint(x*CONTROLSIZE, y*CONTROLSIZE)];
		}
	}
    return self;
}

- (void)mouseMovedToPoint:(NSPoint)p {
    int x, y, i;
    p.x -= _frame.origin.x;
    p.y -= _frame.origin.y;
        
    x = p.x / CONTROLSIZE;
    y = p.y / CONTROLSIZE;
    if (x > 2 || y > 1) {
        NSLog(@"MapControlPanel: Mouse out of bounds %f %f", p.x, p.y);
        return;
    }
    
    i = x + (y * 3);
	NSAssert(i>=0 && i < 6, @"Index is out of bounds");
	[_items[i] mouseEntered:_frame.origin];
}

- (void)mouseDownAtPoint:(NSPoint)p {
    int x, y, i;
    p.x -= _frame.origin.x;
    p.y -= _frame.origin.y;
        
    x = p.x / CONTROLSIZE;
    y = p.y / CONTROLSIZE;
    if (x > 2 || y > 1) {
        NSLog(@"MapControlPanel: Mouse out of bounds %f %f", p.x, p.y);
        return;
    }
    
    i = x + (y * 3);

	NSAssert(i>=0 && i < 6, @"Index is out of bounds");
	[_items[i] mouseClicked:_frame.origin];
    
    switch(i) {
    case 0:
        [[WaveHelper mapView] goLeft:self];
        break;
    case 1:
        [[WaveHelper mapView] goDown:self];
        break;
    case 2:
        [[WaveHelper mapView] goRight:self];
        break;
    case 3:
        [[WaveHelper mapView] zoomIn:self];
        break;
    case 4:
        [[WaveHelper mapView] goUp:self];
        break;
    case 5:
        [[WaveHelper mapView] zoomOut:self];
        break;
    }
}

#pragma mark -

- (void)dealloc {
    int i;
    for (i = 0; i < 6; i++) {
        if (_items[i]) {
            [_items[i] release];
        }
    }
    
    [super dealloc];
}

@end
