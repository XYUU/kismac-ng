/*
        
        File:			PointView.m
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

#import "PointView.h"
#import "WaveHelper.h"
#import "MapView.h"

@implementation PointView

- (void)_genCacheForSize:(int)size {
    NSRect q;
    NSColor *c = [WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"CurrentPositionColor"]];
    NSBezierPath *x;
    float z;
    int w;
    
    if (size < 8) w = size / 2;
    else w = 4;
    
    q.size.height = q.size.width = size;
    q.origin.x = (_frame.size.width  - size) / 2;
    q.origin.y = (_frame.size.height - size) / 2;
    
    for (z=w; z>=-w; z--) {
        [[c blendedColorWithFraction:(((float)abs(z))/w) ofColor:[NSColor clearColor]] set];
        x=[NSBezierPath bezierPathWithOvalInRect:q];
        [x setLineWidth:1.5];
        [x stroke];
        q.origin.x++;
        q.origin.y++;
        q.size.height -= 2;
        q.size.width  -= 2;
    }
}


- (id)init {
    int i;
    self = [super init];
    if (!self) return nil;
    
    [self setSize:NSMakeSize(35, 35)];
    for (i = 2; i <= 35; i++) {
        _currImg[i] = [[NSImage alloc] initWithSize:NSMakeSize(35, 35)];
        [_currImg[i] lockFocus];
        [self _genCacheForSize:i];
        [_currImg[i] unlockFocus];
    }
    _animLock = [[NSLock alloc] init];
    
    [self setImage:_currImg[35]];
    return self;
}

#pragma mark -

- (void)setVisible:(BOOL)visible {
    [super setVisible:visible];
    if (visible) [NSThread detachNewThreadSelector:@selector(animationThread:) toTarget:self withObject:nil];
}

- (void)setLocation:(NSPoint)loc {
    loc.x -= _frame.size.width / 2;
    loc.y -= _frame.size.height / 2;
    [super setLocation:loc];
}

- (void)animationThread:(id)object {
    BOOL e = NO;
    int scale = 35;
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];
    
    if([_animLock tryLock]) {
        [self retain];
        while(_visible) {
            if (e) {
                scale++;
                if (scale>=25) e=NO;
            } else {
                scale--;
                if (scale<=10) e=YES;
            }
            
            [self setImage:_currImg[scale]];
            [[WaveHelper mapView] setNeedsDisplayInMoveRect:_frame];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        [self release];
        [_animLock unlock];
    }

    [subpool release];
}

#pragma mark -

- (void)dealloc {
    int i;
    
    [_animLock release];
    for (i = 0; i <= 35; i++) [_currImg[i] release];
    [super dealloc];
}

@end
