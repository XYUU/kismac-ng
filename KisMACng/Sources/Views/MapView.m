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
#import "NetView.h"
#import "BIImageView.h"
#import "BISubView.h"
#import "BITextView.h"
#import "MapControlPanel.h"
#import "PointView.h"

@implementation MapView

- (void)awakeFromNib {
    _mapImage = nil;
    _wp[0]._lat  = 0; _wp[0]._long = 0;
    _wp[1]._lat  = 0; _wp[1]._long = 0;
    _wp[2]._lat  = 0; _wp[2]._long = 0;
    _zoomFact = 1.0;
    
    _netContainer = [[BISubView alloc] initWithSize:NSMakeSize(30000,30000)];
    [self addSubView:_netContainer];

    _pView = [[PointView alloc] init];
    [_pView setVisible:NO];
    [self addSubView:_pView];
    
    _gpsStatusView = [[BITextView alloc] init];
    [self _setGPSStatus:NSLocalizedString(@"No GPS device available.", "gps status")];
    [self addSubView:_gpsStatusView];
    [_gpsStatusView setLocation:NSMakePoint(-1,-1)];

    _statusView = [[BITextView alloc] init];
    [self _updateStatus];
    [self addSubView:_statusView];
    
    _controlPanel = [[MapControlPanel alloc] init];
    [self _alignControlPanel];
    [self addSubView:_controlPanel];
    
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateGPSStatus:) name:KisMACGPSStatusChanged object:nil];
}

#pragma mark -

- (BOOL)saveToFile:(NSString*)fileName {
    NSFileManager *fMgr;
    NSString *mapName;
    NSData *data;
    NSMutableDictionary *wp[3];
    NSString *error = nil;
    NSBitmapImageRep *img;
    int i;
    
    if (!_orgImage) return NO;
    
    mapName = [fileName stringByExpandingTildeInPath];
    fMgr = [NSFileManager defaultManager];
    [fMgr createDirectoryAtPath:mapName attributes:nil];
        
    data = [_orgImage TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0];
    img = [NSBitmapImageRep imageRepWithData:data];
    data = [img representationUsingType:NSPNGFileType properties:nil];
    [data writeToFile:[mapName stringByAppendingPathComponent:@"map.png"] atomically:NO];
    
    for (i=1;i<=2;i++) {
        wp[i] = [NSMutableDictionary dictionaryWithCapacity:4];
        
        [wp[i] setObject:[NSNumber numberWithFloat:((_wp[i]._lat ) >= 0 ? (_wp[i]._lat ) : -(_wp[i]._lat )) ] forKey:@"latitude" ];
        [wp[i] setObject:((_wp[i]._lat ) >= 0 ? @"N" : @"S") forKey:@"latdir" ];
        [wp[i] setObject:[NSNumber numberWithFloat:((_wp[i]._long) >= 0 ? (_wp[i]._long) : -(_wp[i]._long)) ] forKey:@"longitude"];
        [wp[i] setObject:((_wp[i]._long) >= 0 ? @"E" : @"W") forKey:@"longdir"];
        [wp[i] setObject:[NSNumber numberWithInt:(int)floor(_point[i].x)] forKey:@"xpoint"];
        [wp[i] setObject:[NSNumber numberWithInt:(int)floor(_point[i].y)] forKey:@"ypoint"];
    }
    
    data = [NSPropertyListSerialization dataFromPropertyList:[NSArray arrayWithObjects:wp[1],wp[2],nil] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    
    if (error==Nil) [data writeToFile:[mapName stringByAppendingPathComponent:@"waypoints.plist"] atomically:NO];
    else NSLog(@"Could not write XML File with Coordinates:%@", error);
    
    return (error==Nil);
}

- (BOOL)loadFromFile:(NSString*)fileName {
    NSString *mapName = [fileName stringByExpandingTildeInPath];
    NSString *error = Nil;
    NSArray *wps;
    NSDictionary *wp;
    int i;
    NSData* data;
    NSImage* img;
    waypoint wpoint;
    
    NS_DURING
        img = [[NSImage alloc] initWithContentsOfFile:[mapName stringByAppendingPathComponent:@"map.png"]];
        [self setMap:img];
        [img release];
    NS_HANDLER
        NSLog(@"Could not open Image file from KisMAP bundle!");
        return NO;
    NS_ENDHANDLER
    
    NS_DURING
        data = [NSData dataWithContentsOfFile:[mapName stringByAppendingPathComponent:@"waypoints.plist"]];
        wps = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&error];
    NS_HANDLER
        NSLog(@"Could not open XML File with Coordinates: internal exception raised!");
        return NO;
    NS_ENDHANDLER
    
    if (error!=Nil) {
        NSLog(@"Could not open XML File with Coordinates: %@", error);
        return NO; 
    }
    
    for (i=1;i<=2;i++) {
        wp = [wps objectAtIndex:i-1];
        
        wpoint._lat = [[wp objectForKey:@"latitude" ] floatValue];
        wpoint._long= [[wp objectForKey:@"longitude"] floatValue];
        if ([[wp objectForKey:@"latdir" ] isEqualToString:@"S"]) wpoint._lat *=-1;
        if ([[wp objectForKey:@"longdir"] isEqualToString:@"W"]) wpoint._long*=-1;
        
        [self setWaypoint:i toPoint:NSMakePoint([[wp objectForKey:@"xpoint"] intValue], [[wp objectForKey:@"ypoint"] intValue]) atCoordinate:wpoint];
    }
    
    return YES;
}

#pragma mark -

- (BOOL)setMap:(NSImage*)map {
    [WaveHelper secureReplace:&_orgImage withObject:map];
    [WaveHelper secureReplace:&_mapImage withObject:map];
    _wp[0]._lat  = 0; _wp[0]._long = 0;
    _wp[1]._lat  = 0; _wp[1]._long = 0;
    _wp[2]._lat  = 0; _wp[2]._long = 0;
    _center.x = [_mapImage size].width  / 2;
    _center.y = [_mapImage size].height / 2;
    _zoomFact = 1.0;
    
    [self _updateStatus];
    [self _alignNetworks];
    [self setNeedsDisplay:YES];
    
    return YES;
}

- (void)setWaypoint:(int)which toPoint:(NSPoint)point atCoordinate:(waypoint)coord {
    _point[which] = point;
    _wp[which] = coord;
 
    [self _updateStatus];
    [self _alignNetworks];
    [self setNeedsDisplay:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:KisMACAdvNetViewInvalid object:self];
}

- (void)setVisible:(BOOL)visible {
    _visible = visible;
    [_pView setVisible:visible];
}

- (NSPoint)pixelForCoordinate:(waypoint)wp {
    NSPoint p;
    if ([_statusView visible]) return INVALIDPOINT;
    
    NS_DURING
        p.x = ((_point[1].x - (_wp[1]._long- wp._long) / (_wp[1]._long-_wp[2]._long) * (_point[1].x-_point[2].x)) * _zoomFact);
        p.y = ((_point[1].y - (_wp[1]._lat - wp._lat)  / (_wp[1]._lat - _wp[2]._lat) * (_point[1].y-_point[2].y)) * _zoomFact);
    NS_HANDLER
        return INVALIDPOINT;
    NS_ENDHANDLER

    return p;
}

- (void)addNetView:(NetView*)view {
    [_netContainer addSubView:view];
}

- (void)removeNetView:(NetView*)view {
    [_netContainer removeSubView:view];
}

#pragma mark -

- (void)drawRectSub:(NSRect)rect { 
    [_mapImage drawInRect:rect fromRect:NSMakeRect(_center.x + ((rect.origin.x - (_frame.size.width / 2)) / _zoomFact), _center.y + ((rect.origin.y - (_frame.size.height / 2)) / _zoomFact), rect.size.width / _zoomFact, rect.size.height / _zoomFact) operation:NSCompositeCopy fraction:1.0];
}
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self _align];
    [self _alignStatus];
    [self _alignControlPanel];
}
- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self _align];
    [self _alignStatus];
    [self _alignControlPanel];
}

- (void)keyDown:(NSEvent *)theEvent {
    switch ([theEvent keyCode]) {
    case 123:
        [self goLeft:self];
        break;
    case 124:
        [self goRight:self];
        break;
    case 125:
        [self goDown:self];
        break;
    case 126:
        [self goUp:self];
        break;
    case 44: //minus key
        [self zoomOut:self];
        break;
    case 30: //plus key
        [self zoomIn:self];
        break;
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    NSPoint p;
    p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (NSPointInRect(p, [_controlPanel frame])) [_controlPanel mouseMovedToPoint:p];
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint p;
    p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (NSPointInRect(p, [_controlPanel frame])) [_controlPanel mouseDownAtPoint:p];
}

#pragma mark -

- (void)setShowNetworks:(BOOL)show {
    [_netContainer setVisible:show];
    [_showNetworks setState:(show ? NSOnState : NSOffState)];
    [self setNeedsDisplay:YES];
}

#define ZOOMFACT 1.5
- (IBAction)zoomIn:(id)sender {
    if (_zoomFact > 20) {
        NSBeep();
        return;
    }
    _zoomFact *= ZOOMFACT;
    [self _alignNetworks];
    [self setNeedsDisplay:YES];
}

- (IBAction)zoomOut:(id)sender {
    if (_zoomFact < 0.1) {
        NSBeep();
        return;
    }    
    _zoomFact /= ZOOMFACT;
    [self _alignNetworks];
    [self setNeedsDisplay:YES];
}

- (IBAction)goLeft:(id)sender {
    _center.x -= 40.0 / _zoomFact;
    [self _align];
    [self setNeedsDisplay:YES];
}
- (IBAction)goRight:(id)sender{
    _center.x += 40.0 / _zoomFact;
    [self _align];
    [self setNeedsDisplay:YES];
}
- (IBAction)goUp:(id)sender {
    _center.y += 40.0 / _zoomFact;
    [self _align];
    [self setNeedsDisplay:YES];
}
- (IBAction)goDown:(id)sender {
    _center.y -= 40.0 / _zoomFact;
    [self _align];
    [self setNeedsDisplay:YES];
}

#pragma mark -

- (void)dealloc {
    [self unsubscribeNotifications];
    
    [_controlPanel release];
    [_netContainer release];
    [_status release];
    [_statusView release];
    [_gpsStatus release];
    [_gpsStatusView release];
    [_mapImage release];
    [_orgImage release];
    [_pView release];
    
    [super dealloc];
}

@end
