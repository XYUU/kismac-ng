/*
        
        File:			MapViewPrivate.m
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

#import "MapViewPrivate.h"
#import "WaveHelper.h"

@implementation MapView(Private)

#define CLIPSIZE 1024.0

- (void)_align {
    NSPoint loc;

    loc.x = (_frame.size.width - [_statusImg size].width)  / 2;
    loc.y = (_frame.size.height- [_statusImg size].height) / 2;
    [_statusView setLocation:loc];
    
    if (_clipX) {
        loc.x =  (_frame.size.width - CLIPSIZE) / 2.0;
    } else {
        loc.x =  (_frame.size.width  / 2) + ((_center.x - _clipOffset.x - [_mapImage size].width)  * _zoomFact);
    }
    
    if (_clipY) {
        loc.y =  (_frame.size.height - CLIPSIZE) / 2.0;
    } else {
        loc.y =  (_frame.size.height / 2) + ((_center.y - _clipOffset.y - [_mapImage size].height) * _zoomFact) ;
    }
    [_map setLocation:loc];
}

- (void)_adjustZoom {
    NSSize mapImageSize = [_mapImage size];
    NSImage *img;
    NSSize startSize, finalSize;
    NSPoint clipStart = NSZeroPoint;
    _clipX = _clipY = NO;
    
    //_center needs to be at new size already!!!
    if ((mapImageSize.width * _zoomFact) > CLIPSIZE) {  // we need to clip something away :/
        _clipX = YES;
        startSize.width = CLIPSIZE / _zoomFact;
        finalSize.width = CLIPSIZE;
        clipStart.x = mapImageSize.width - _center.x - (CLIPSIZE / 2.0 / _zoomFact);
    } else {
        finalSize.width = mapImageSize.width * _zoomFact;
        startSize.width = mapImageSize.width;
    }
    
    if ((mapImageSize.height * _zoomFact) > CLIPSIZE) { // we need to clip something away :/
        _clipY = YES;
        finalSize.height = CLIPSIZE;
        startSize.height = CLIPSIZE / _zoomFact;
        clipStart.y = mapImageSize.height -_center.y - (CLIPSIZE / 2.0 / _zoomFact);
    } else {
        finalSize.height = mapImageSize.height * _zoomFact;
        startSize.height = mapImageSize.height;
    }
    img = [[NSImage alloc] initWithSize:finalSize];
    
    [img lockFocus];
    [_mapImage drawInRect:NSMakeRect(0, 0, finalSize.width, finalSize.height) fromRect:NSMakeRect(clipStart.x, clipStart.y, startSize.width, startSize.height) operation:NSCompositeCopy fraction:1.0];
    [img unlockFocus];

    NS_DURING
        [_map setImage:img];
    NS_HANDLER
        NSLog(@"Image is probably too big :(");
    NS_ENDHANDLER
    
    [img release];
}

- (void)_setStatus:(NSString*)status {
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:14];
    NSSize size;
    NSColor *red = [NSColor colorWithCalibratedRed:1 green:0 blue:0 alpha:1];
    
    [WaveHelper secureReplace:&_status withObject:status];
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:red forKey:NSForegroundColorAttributeName];
    
    size = [_status sizeWithAttributes:attrs];
    size.width += 20;
    size.height += 10;
    
    [WaveHelper secureReplace:&_statusImg withObject:[[[NSImage alloc] initWithSize:size] autorelease]];
    [_statusImg lockFocus];
    [[NSColor colorWithCalibratedRed:0.3 green:0 blue:0 alpha:0.5] set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(0,0,size.width,size.height)] fill];
    [red set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(1,1,size.width-2,size.height-2)] stroke];
    [_status drawAtPoint:NSMakePoint(10,5) withAttributes:attrs];
    [_statusImg unlockFocus];
    
    [_statusView setImage:_statusImg];
    [self _align];
    if (_visible) [self setNeedsDisplay:YES];
}

- (void)_updateStatus {
    if (!_mapImage) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"No map loaded! Please import or load one first.", "map view status")];
    } else if (_wp[selWaypoint1]._lat == 0 && _wp[selWaypoint1]._long == 0) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"Waypoint 1 is not set!", "map view status")];
    } else if (_wp[selWaypoint2]._lat == 0 && _wp[selWaypoint2]._long == 0) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"Waypoint 2 is not set!", "map view status")];
    } else {
        [_statusView setVisible:NO];
        if (_visible) [self setNeedsDisplay:YES];
    }
}

- (void)_setGPSStatus:(NSString*)status {
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSColor *grey = [NSColor whiteColor];
    
    [WaveHelper secureReplace:&_gpsStatus withObject:status];
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:grey forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *a = [[[NSAttributedString alloc] initWithString:_gpsStatus attributes:attrs] autorelease];
    [_gpsStatusView setString:a];
    [_gpsStatusView setBorderColor:grey];
    [_gpsStatusView setBackgroundColor:[[NSColor darkGrayColor] colorWithAlphaComponent:0.5]];
    
    if (_visible) [self setNeedsDisplay:YES];
}

- (void)_updateGPSStatus:(NSNotification*)note {
    if ([(NSString*)[note object] compare:_gpsStatus] == NSOrderedSame) return;
    [self _setGPSStatus:[note object]];
}

@end
