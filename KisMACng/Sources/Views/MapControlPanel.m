/*
        
        File:			MapControlPanel.m
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

#import "MapControlPanel.h"
#import "WaveHelper.h"
#import "MapView.h"

#define CONTROLSIZE 30.0
#define CURVERAD 5.0
#define BORDER 1.0
#define OFFSET (CURVERAD + BORDER)
#define TRIANGLESIZE 15.0

inline col fillColor() {
    col c;
    c.red = 35.0/255.0;
    c.green = 45.33333/255.0;
    c.blue = 58.666/255.0;
    c.alpha = .5;
    return c;
}

inline col borderColor() {
    col c;
    c.red = 105.0/255.0;
    c.green = 136.0/255.0;
    c.blue = 175.0/255.0;
    c.alpha = 1.0;
    return c;
}

inline col highBorderColor() {
    col c;
    c.red = 1;
    c.green = 1;
    c.blue = 1;
    c.alpha = 1;
    return c;
}

inline col highFillColor() {
    col c;
    c.red = .333333;
    c.green = .333333;
    c.blue = .333333;
    c.alpha = .5;
    return c;
}

inline col clickBorderColor() {
    return fillColor();
}

inline col clickFillColor() {
    return borderColor();
}

inline NSColor* col2NSColor(col c) {
    return [NSColor colorWithDeviceRed:c.red green:c.green blue:c.blue alpha:c.alpha];
}

inline col delta(col c1, col c2, int speed) {
    col c;
    c.red   = (c1.red   - c2.red)   / speed;
    c.green = (c1.green - c2.green) / speed;
    c.blue  = (c1.blue  - c2.blue)  / speed;
    c.alpha = (c1.alpha - c2.alpha) / speed;
    return c;
}

@implementation MapControlPanel

- (void)_drawFrameAtPoint:(NSPoint)p index:(int)index {
    NSBezierPath *b = [NSBezierPath bezierPath];
    
    [b moveToPoint:NSMakePoint(p.x+OFFSET, p.y+BORDER)];
    
    [b appendBezierPathWithArcWithCenter:NSMakePoint(p.x + CONTROLSIZE - OFFSET, p.y + OFFSET) radius:CURVERAD
			       startAngle:270
				 endAngle:0];
    [b appendBezierPathWithArcWithCenter:NSMakePoint(p.x + CONTROLSIZE - OFFSET, p.y + CONTROLSIZE - OFFSET) radius:CURVERAD
			       startAngle:0
				 endAngle:90];
    [b appendBezierPathWithArcWithCenter:NSMakePoint(p.x + OFFSET, p.y + CONTROLSIZE - OFFSET) radius:CURVERAD
			       startAngle:90
				 endAngle:180];
    [b appendBezierPathWithArcWithCenter:NSMakePoint(p.x + OFFSET, p.y + OFFSET) radius:CURVERAD
			       startAngle:180
				 endAngle:270];
    [b closePath];
    
    [col2NSColor(_current[index].fill) set];
    [b fill];
    
    [col2NSColor(_current[index].border) set];
    [b stroke];
    
    b = [NSBezierPath bezierPath];
    switch (index) {
    case 0:
        [b moveToPoint:NSMakePoint(p.x + CONTROLSIZE/2 + TRIANGLESIZE/2 - BORDER, p.y + CONTROLSIZE/2 - TRIANGLESIZE/2)];
        [b relativeLineToPoint:NSMakePoint(0, TRIANGLESIZE)];
        [b relativeLineToPoint:NSMakePoint(-TRIANGLESIZE, -TRIANGLESIZE/2)];
        break;
    case 1:
        [b moveToPoint:NSMakePoint(p.x + CONTROLSIZE/2 - TRIANGLESIZE/2, p.y + CONTROLSIZE/2 + TRIANGLESIZE/2)];
        [b relativeLineToPoint:NSMakePoint(TRIANGLESIZE, 0)];
        [b relativeLineToPoint:NSMakePoint(-TRIANGLESIZE/2, -TRIANGLESIZE)];
        break;
    case 2:
        [b moveToPoint:NSMakePoint(p.x + CONTROLSIZE/2 - TRIANGLESIZE/2 - BORDER, p.y + CONTROLSIZE/2 - TRIANGLESIZE/2)];
        [b relativeLineToPoint:NSMakePoint(0, TRIANGLESIZE)];
        [b relativeLineToPoint:NSMakePoint(TRIANGLESIZE, -TRIANGLESIZE/2)];
        break;
    case 3:
        [b moveToPoint:NSMakePoint(p.x + CONTROLSIZE/2, p.y + CONTROLSIZE/2)];
        [b appendBezierPathWithRect:NSMakeRect(p.x + CONTROLSIZE/2 - TRIANGLESIZE/8, p.y + CONTROLSIZE/2 - TRIANGLESIZE/2, TRIANGLESIZE/4, TRIANGLESIZE)];
    case 5:
        [b moveToPoint:NSMakePoint(p.x + CONTROLSIZE/2, p.y + CONTROLSIZE/2)];
        [b appendBezierPathWithRect:NSMakeRect(p.x + CONTROLSIZE/2 - TRIANGLESIZE/2, p.y + CONTROLSIZE/2 - TRIANGLESIZE/8, TRIANGLESIZE, TRIANGLESIZE/4)];
        break;
    case 4:
        [b moveToPoint:NSMakePoint(p.x + CONTROLSIZE/2 - TRIANGLESIZE/2, p.y + CONTROLSIZE/2 - TRIANGLESIZE/2)];
        [b relativeLineToPoint:NSMakePoint(TRIANGLESIZE, 0)];
        [b relativeLineToPoint:NSMakePoint(-TRIANGLESIZE/2, TRIANGLESIZE)];
        break;
    }
    [b closePath];
    [b fill];
}

- (void)_generateCache {
    int x, y;
    
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(CONTROLSIZE*3, CONTROLSIZE*2)];
    [img lockFocus];
    for (x=0; x<3; x++) 
        for (y=0; y<2; y++)
            [self _drawFrameAtPoint:NSMakePoint(x*CONTROLSIZE, y*CONTROLSIZE) index:(x + (y * 3))];
    [img unlockFocus];
    [self setImage:img];
    [img release];
}

- (id)init {
    int i;
    self = [super init];
    if (!self) return nil;
    
    _zoomLock = [[NSLock alloc] init];
    for (i = 0; i < 6; i++) {
        _current[i].fill    = fillColor();
        _current[i].border  = borderColor();
    }
    [self _generateCache];
    
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
    _target[i].fill    = highFillColor();
    _target[i].border  = highBorderColor();
    _delta[i].fill   = delta(_target[i].fill  , _current[i].fill, 5);
    _delta[i].border = delta(_target[i].border, _current[i].border, 5);
    
    [NSThread detachNewThreadSelector:@selector(zoomThread:) toTarget:self withObject:nil];

    if (_timeouts[i]) {
        [_timeouts[i] invalidate];
    }
    _timeouts[i] = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeout:) userInfo:[NSNumber numberWithInt:i] repeats:NO];
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
    _target[i].fill    = clickFillColor();
    _target[i].border  = clickBorderColor();
    _delta[i].fill   = delta(_target[i].fill  , _current[i].fill, 1);
    _delta[i].border = delta(_target[i].border, _current[i].border, 1);
    
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
    [NSThread detachNewThreadSelector:@selector(zoomThread:) toTarget:self withObject:nil];

    if (_timeouts[i]) {
        [_timeouts[i] invalidate];
    }
    _timeouts[i] = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timeout:) userInfo:[NSNumber numberWithInt:i] repeats:NO];
}

- (void)timeout:(NSTimer*)timer {
    int i = [[timer userInfo] intValue];
    _target[i].fill    = fillColor();
    _target[i].border  = borderColor();
    _delta[i].fill   = delta(_target[i].fill  , _current[i].fill, 20);
    _delta[i].border = delta(_target[i].border, _current[i].border, 20);
    
    [NSThread detachNewThreadSelector:@selector(zoomThread:) toTarget:self withObject:nil];
    _timeouts[i] = NULL;
}

#define ADJUSTCOMP(INDEX, COMP) if (_delta[INDEX].COMP != 0 && (_delta[INDEX].COMP > 0 ? _target[INDEX].COMP > _current[INDEX].COMP : _target[INDEX].COMP < _current[INDEX].COMP)) { _current[INDEX].COMP += _delta[INDEX].COMP; didSomething = YES;  }
#define ADJUSTX(INDEX,X) ADJUSTCOMP(INDEX, X.red) ADJUSTCOMP(INDEX, X.green) ADJUSTCOMP(INDEX, X.blue) ADJUSTCOMP(INDEX, X.alpha)

- (void)zoomThread:(id)object {
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];
    BOOL didSomething;
    int i;
    
    if([_zoomLock tryLock]) {
        [self retain];
        while(YES) {
            didSomething = NO;
            for (i = 0; i < 6; i++) {
                ADJUSTX(i, fill);
                ADJUSTX(i, border);
            }
            if (!didSomething) break;
            [self _generateCache];
            [[WaveHelper mapView] setNeedsDisplayInRect:_frame];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        [self release];
        [_zoomLock unlock];
    }

    [subpool release];
}


#pragma mark -

- (void)dealloc {
    int i;
    for (i = 0; i < 6; i++) {
        if (_timeouts[i]) {
            [_timeouts[i] invalidate];
        }
    }
    
    [_zoomLock release];
    [super dealloc];
}

@end
