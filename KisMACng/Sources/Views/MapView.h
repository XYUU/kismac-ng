/*
        
        File:			MapView.h
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

#import <Cocoa/Cocoa.h>
#import <BIGL/BIGL.h>
#import <BIGeneric/BIValuePair.h>

enum selmode {
    selCurPos = 0,
    selWaypoint1 = 1,
    selWaypoint2 = 2,
};

@interface MapView : BIGLView {
    NSString            *_status;
    NSImage             *_statusImg;
    NSString            *_gpsStatus;
    BIGLImageView       *_map;
    BIGLImageView       *_statusView;
    BIGLTextView        *_gpsStatusView;
    BOOL                _visible;
    NSImage             *_mapImage;
    NSImage             *_orgImage;
    
    waypoint            _wp[3];
    NSPoint             _old;
    NSPoint             _point[3];
    NSPoint             _center;
    NSPoint             _clipOffset;
    float               _zoomFact;
    
    BOOL                _clipX, _clipY;
    enum selmode        _selmode;
}

- (BOOL)setMap:(NSImage*)map;
- (void)setWaypoint:(int)which toPoint:(NSPoint)point atCoordinate:(waypoint)coord;
- (void)setVisible:(BOOL)visible;

- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

@end
