/*
        
        File:			ZoomPictureView.h
        Program:		KisMAC
	Author:			Michael Ro§berg
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

#import <AppKit/AppKit.h>
#import "Waypoint.h"
#import "WaypointView.h"
#import "TraceView.h"
#import "AdvNetView.h"

@class CustomScrollView;

@interface ZoomPictureView : NSImageView {
    NSLock* _Lock;
    
    bool _waitForWaypoint;
    bool _showNetworks;
    
    IBOutlet NSView* _parentView;
    IBOutlet CustomScrollView* _scrollView;
    
    IBOutlet WayPointView* _wpView;
    
    IBOutlet NSMenuItem* _wp1;
    IBOutlet NSMenuItem* _wp2;
    IBOutlet NSMenuItem* _scp;
    IBOutlet NSMenuItem* _cp;

    IBOutlet NSMenuItem* _sTrace;

    AdvNetView *_advNetView;
    TraceView *_trace;
    
    waypoint _wp[3];
    NSPoint _old;
    NSPoint _point[3];

    int selmode;
    
    waypointdlg aWPD;
    WayPoint *aWayPoint;
    NSModalSession aMS;
}

- (BOOL)loadFromFile:(NSString*)fileName;
- (void)saveToFile:(NSString*)fileName;

- (void)clearAdvNet;
- (void)showAdvNet:(WaveNet*)net;
- (void)showAdvNets:(NSArray*)nets;

- (void)alignPoint;
- (void)calcPixelforNS:(double)ns EW:(double)ew forPoint:(NSPoint*)p;
- (void)calcPixelNoZoomforNS:(double)ns EW:(double)ew forPoint:(NSPoint*)p;
- (void)setCurrentPoint:(waypoint) wp;
- (void)setWaypoint:(int)which toPoint:(NSPoint)point atCoordinate:(waypoint)coord;
- (void)waitThread:(id)object;
- (void)setVisible:(bool)visible;
- (NSPoint)currentPosition;
- (double)getPixelPerDegree;
- (double)getPixelPerDegreeNoZoom;

- (IBAction)setWaypoint1:(id)sender;
- (IBAction)setWaypoint2:(id)sender;
- (IBAction)setNoWayPoint:(id)sender;
- (IBAction)setCP:(id)sender;
- (IBAction)showTrace:(id)sender;
- (IBAction)resetTrace:(id)sender;
- (IBAction)setShowNetworks:(id)sender;

@end
