/*
        
        File:			MapView.m
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

#import "MapView.h"
#import "WaveHelper.h"
#import "KisMACNotifications.h"
#import "MapViewPrivate.h"
#import <BIGeneric/BIGeneric.h>

@implementation MapView

- (void)awakeFromNib {
    _mapImage = nil;
    _wp[0]._lat  = 0; _wp[0]._long = 0;
    _wp[1]._lat  = 0; _wp[1]._long = 0;
    _wp[2]._lat  = 0; _wp[2]._long = 0;
    _zoomFact = 1.0;
    
    [self setBackgroundColor:[NSColor blackColor]];
        
    _map = [[BIGLImageView alloc] init];
    [_map setVisible:NO];
    [self addSubView:_map];
    
    _gpsStatusView = [[BIGLTextView alloc] init];
    [self _setGPSStatus:NSLocalizedString(@"No GPS device available.", "gps status")];
    [self addSubView:_gpsStatusView];
    [_gpsStatusView setLocation:NSMakePoint(-1,-1)];

    _statusView = [[BIGLImageView alloc] init];
    [self _updateStatus];
    [self addSubView:_statusView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateGPSStatus:) name:KisMACGPSStatusChanged object:nil];
}

#pragma mark -

- (BOOL)setMap:(NSImage*)map {
    [WaveHelper secureReplace:&_orgImage withObject:map];
    [WaveHelper secureReplace:&_mapImage withObject:map];
    [_map setImage:_mapImage];
    [_map setVisible:YES];
    _wp[0]._lat  = 0; _wp[0]._long = 0;
    _wp[1]._lat  = 0; _wp[1]._long = 0;
    _wp[2]._lat  = 0; _wp[2]._long = 0;
    _center.x = [_mapImage size].width  / 2;
    _center.y = [_mapImage size].height / 2;
    _zoomFact = 1.0;
    
    [self _updateStatus];
    [self _adjustZoom];
    [self _align];
    
    return YES;
}

- (void)setWaypoint:(int)which toPoint:(NSPoint)point atCoordinate:(waypoint)coord {
    _point[which] = point;
    _wp[which] = coord;
    [self _updateStatus];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:KisMACAdvNetViewInvalid object:self];
}

- (void)setVisible:(BOOL)visible {
    _visible = visible;
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self _align];
}
- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self _align];
}

- (void)keyDown:(NSEvent *)theEvent {
    switch ([theEvent keyCode]) {
    case 123:
        _center.x += 40.0;
        [self _adjustZoom];
        [self _align];
        [self setNeedsDisplay:YES];
        break;
    case 124:
        _center.x -= 40.0;
        [self _adjustZoom];
        [self _align];
        [self setNeedsDisplay:YES];
        break;
    case 125:
        _center.y += 40.0;
        [self _adjustZoom];
        [self _align];
        [self setNeedsDisplay:YES];
        break;
    case 126:
        _center.y -= 40.0;
        [self _adjustZoom];
        [self _align];
        [self setNeedsDisplay:YES];
        break;
    case 44: //minus key
        [self zoomOut:self];
        break;
    case 30: //plus key
        [self zoomIn:self];
        break;
    }
}
#pragma mark -

#define ZOOMFACT 1.5
- (IBAction)zoomIn:(id)sender {
    if (_zoomFact > 20) {
        NSBeep();
        return;
    }
    _zoomFact *= ZOOMFACT;
    [self _adjustZoom];
    [self _align];
    [self setNeedsDisplay:YES];
}

- (IBAction)zoomOut:(id)sender {
    if (_zoomFact < 0.1) {
        NSBeep();
        return;
    }    
    _zoomFact /= ZOOMFACT;
    [self _adjustZoom];
    [self _align];
    [self setNeedsDisplay:YES];
}

#pragma mark -

- (void)dealloc {
    [self unsubscribeNotifications];
    
    [_status release];
    [_statusImg release];
    [_statusView release];
    [_gpsStatus release];
    [_gpsStatusView release];
    [_map release];
    [_mapImage release];
    [_orgImage release];
    
    [super dealloc];
}

@end
