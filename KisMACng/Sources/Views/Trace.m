/*
        
        File:			Trace.m
        Program:		KisMAC
	Author:			Michael Rossberg
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

#import "Trace.h"
#import "WaveHelper.h"
#import "MapView.h"

@implementation Trace

- (id)init {
    self = [super init];
    if (!self) return nil;
    
    _trace = [[NSMutableArray array] retain];
    _state = stateNoPointPresent;
    return self;
}

- (BOOL)addPoint:(waypoint)w {
    NSMutableArray* a;
    waypoint old;
    
    switch(_state) {
    case stateNoPointPresent:
        [_lastPoint autorelease];
        _lastPoint = [[BIValuePair valuePairFromWaypoint:w] retain];
        _state = stateFirstPointPresent;
        break;
    case stateFirstPointPresent:
        old = [_lastPoint wayPoint];
        if (w._long == old._long && w._lat == old._lat) return NO;
        a = [NSMutableArray arrayWithObjects:_lastPoint, [BIValuePair valuePairFromWaypoint:w], nil];
        [_trace addObject:a];
        _state = stateMultiPointsPresent;
        break;
    case stateMultiPointsPresent:
        old = [[[_trace lastObject] lastObject] wayPoint];
        if (w._long == old._long && w._lat == old._lat) return NO;
        [[_trace lastObject] addObject:[BIValuePair valuePairFromWaypoint:w]];
        break;
    }
    return YES;
}

- (void)cut {
    _state = stateNoPointPresent;
}

- (BOOL)setTrace:(NSMutableArray*)trace {
    [_trace autorelease];
    if (!trace) _trace = [NSMutableArray array];
    else _trace = trace;
    [_trace retain];
    _state = stateNoPointPresent;
    return YES;
}

- (NSMutableArray*)trace {
    return _trace;
}

#pragma mark -

- (void)drawSubAtPoint:(NSPoint)p inRect:(NSRect)rect {
    MapView *m;
    NSBezierPath *b;
    NSPoint p2;
    int i, j;
    NSArray *tour;
    NSColor *color = [WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"TraceColor"]];
    NSAffineTransform *t;
    
    if ([_trace count] == 0) return;
    [color set];
    
    m = [WaveHelper mapView];
    t = [NSAffineTransform transform];
    [t translateXBy:p.x yBy:p.y];
    
    for (i = 0; i < [_trace count]; i++) {
        tour = [_trace objectAtIndex:i];
        b = [NSBezierPath bezierPath];
        p2 = [m pixelForCoordinate:[[tour objectAtIndex:0] wayPoint]];
        [b moveToPoint:p2];
        for (j = 1; j < [tour count]; j++) {
            p2 = [m pixelForCoordinate:[[tour objectAtIndex:j] wayPoint]];
            [b lineToPoint:p2];        
        }
        [b transformUsingAffineTransform:t];
        [b setLineWidth:2];
        [b stroke];
    }
}

#pragma mark -

- (void)dealloc {
    [_trace release];
    [_lastPoint release];
    [super dealloc];
}
@end