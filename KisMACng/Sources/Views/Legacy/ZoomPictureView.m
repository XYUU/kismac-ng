/*
        
        File:			ZoomPictureView.m
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

#import "ZoomPictureView.h"
#import "WaveHelper.h"
#import "NetView.h"
#import "CustomScrollView.h"

extern NSString *const KisMACAdvNetViewInvalid;

@implementation ZoomPictureView

- (void)awakeFromNib {
    _Lock = [[NSLock alloc] init];    
    _waitForWaypoint = NO;
    _point[0].x = -100;
    _point[0].y = -100;
    _showNetworks = YES;
}

#pragma mark -

- (void)saveToFile:(NSString*)fileName {
    NSFileManager *aMgr;
    NSString *aMapName;
    NSData *aData;
    NSMutableDictionary *aWP[3];
    NSString *aError = nil;
    NSBitmapImageRep *img;
    NSSize s;
    NSRect f;
    int i;
    double d;
    
    aMapName = [fileName stringByExpandingTildeInPath];
    aMgr = [NSFileManager defaultManager];
    [aMgr createDirectoryAtPath:aMapName attributes:nil];
        
    aData = [[[WaveHelper zoomPictureView] image] TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0];
    img = [NSBitmapImageRep imageRepWithData:aData];
    aData = [img representationUsingType:NSPNGFileType properties:nil];
    [aData writeToFile:[aMapName stringByAppendingPathComponent:@"map.png"] atomically:NO];
    
    for (i=1;i<=2;i++) {
        aWP[i] = [NSMutableDictionary dictionaryWithCapacity:4];
        
        [aWP[i] setObject:[NSNumber numberWithFloat:((_wp[i]._lat ) >= 0 ? (_wp[i]._lat ) : -(_wp[i]._lat )) ] forKey:@"latitude" ];
        [aWP[i] setObject:((_wp[i]._lat ) >= 0 ? @"N" : @"S") forKey:@"latdir" ];
        [aWP[i] setObject:[NSNumber numberWithFloat:((_wp[i]._long) >= 0 ? (_wp[i]._long) : -(_wp[i]._long)) ] forKey:@"longitude"];
        [aWP[i] setObject:((_wp[i]._long) >= 0 ? @"E" : @"W") forKey:@"longdir"];
        s = [[super image] size];
        f = [self frame];
        d = _point[i].x * s.width / f.size.width;
        [aWP[i] setObject:[NSNumber numberWithInt:(int)floor(d)] forKey:@"xpoint"];
        d = _point[i].y * s.height / f.size.height;
        [aWP[i] setObject:[NSNumber numberWithInt:(int)floor(d)] forKey:@"ypoint"];
    }
    
    aData = [NSPropertyListSerialization dataFromPropertyList:[NSArray arrayWithObjects:aWP[1],aWP[2],nil] format:NSPropertyListXMLFormat_v1_0 errorDescription:&aError];
    
    if (aError==Nil) [aData writeToFile:[aMapName stringByAppendingPathComponent:@"waypoints.plist"] atomically:NO];
    else NSLog(@"Could not write XML File with Coordinates:%@",aError);   
}

- (BOOL)loadFromFile:(NSString*)fileName {
    NSString *aMapName = [fileName stringByExpandingTildeInPath];
    NSString *aError = Nil;
    NSPropertyListFormat aFormat;
    NSArray *aWPs;
    NSDictionary *aWP;
    int i;
    NSData* data;
    NSImage* img;
    
    NS_DURING
        img = [[NSImage alloc] initWithContentsOfFile:[aMapName stringByAppendingPathComponent:@"map.png"]];
        [self setImage: img];
        [img release];
    NS_HANDLER
        NSLog(@"Could not open Image file from KisMAP bundle!");
        return NO;
    NS_ENDHANDLER
    
    NS_DURING
        data = [NSData dataWithContentsOfFile:[aMapName stringByAppendingPathComponent:@"waypoints.plist"]];
        aWPs = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:&aFormat errorDescription:&aError];
    NS_HANDLER
        NSLog(@"Could not open XML File with Coordinates: internal exception raised!");
        return NO;
    NS_ENDHANDLER
    
    if (aError!=Nil) {
        NSLog(@"Could not open XML File with Coordinates:%@",aError);
        return NO; 
    }
    
    for (i=1;i<=2;i++) {
        aWP = [aWPs objectAtIndex:i-1];
        
        _wp[i]._lat = [[aWP objectForKey:@"latitude" ] floatValue];
        _wp[i]._long= [[aWP objectForKey:@"longitude"] floatValue];
        if ([[aWP objectForKey:@"latdir" ] isEqualToString:@"S"]) _wp[i]._lat *=-1;
        if ([[aWP objectForKey:@"longdir"] isEqualToString:@"W"]) _wp[i]._long*=-1;
        
        _point[i].x = [[aWP objectForKey:@"xpoint" ] intValue];
        _point[i].y = [[aWP objectForKey:@"ypoint" ] intValue];
    }
    
    [_scrollView setFrame:[_scrollView frame]];
    return YES;
}

#pragma mark -

- (void)addSubview:(NSView *)aView {
    NetView *n;
    
    [super addSubview:aView];
    if ([aView isMemberOfClass:[NetView class]]) {
        n = (NetView*)aView;
        [n setNetVisible:_showNetworks];
    }
}

- (void)clearAdvNet {
    if (_advNetView) {
        [_advNetView clearMap];
        [_advNetView removeFromSuperview];
        [_advNetView release];
        _advNetView = Nil;
    }

}

- (void)showAdvNet:(WaveNet*)net {
    if (!_advNetView) {
        _advNetView = [[AdvNetView alloc] init];
        [self addSubview:_advNetView];
        [_advNetView setFrame: _frame];
    }
    [_advNetView showNetwork: net];
}

- (void)showAdvNets:(NSArray*)nets {
    if (!_advNetView) {
        _advNetView = [[AdvNetView alloc] init];
        [self addSubview:_advNetView];
        [_advNetView setFrame: _frame];
    }
    [_advNetView showAllNetworks:nets];
}

- (NSPoint)currentPosition {
    return _point[0];
}

- (void)calcPixelforNS:(double)ns EW:(double)ew forPoint:(NSPoint*)p {
    double x,y;
    NS_DURING
        x =(double)(_point[1].x - (_wp[1]._long - ew) / (_wp[1]._long-_wp[2]._long) * (_point[1].x - _point[2].x));
        y =(double)(_point[1].y - (_wp[1]._lat  - ns) / (_wp[1]._lat -_wp[2]._lat)  * (_point[1].y - _point[2].y));
    NS_HANDLER
        x = -100.0;
        y = -100.0;
    NS_ENDHANDLER
    *p = NSMakePoint(x, y);
}

- (void)calcPixelNoZoomforNS:(double)ns EW:(double)ew forPoint:(NSPoint*)p {
    double x,y;
    NSRect f;
    NSSize s;
    
    f = [self frame];
    s = [[super image] size];
    NS_DURING
        x =(double)(_point[1].x * s.width / f.size.width - (_wp[1]._long - ew) / (_wp[1]._long-_wp[2]._long) * 
        (_point[1].x - _point[2].x) * s.width / f.size.width);
        y =(double)(_point[1].y * s.width / f.size.width - (_wp[1]._lat  - ns) / (_wp[1]._lat -_wp[2]._lat)  * 
        (_point[1].y - _point[2].y) * s.width / f.size.width);
    NS_HANDLER
        x = -100.0;
        y = -100.0;
    NS_ENDHANDLER
    *p = NSMakePoint(x, y);
}

- (double)getPixelPerDegree {
    double val1, val2;
    NS_DURING
        val1 = (_point[1].x - _point[2].x)  / (_wp[1]._long-_wp[2]._long);
        val2 = (_point[1].y - _point[2].y) /  (_wp[1]._lat -_wp[2]._lat );
    NS_HANDLER
        val1 = 0.0;
        val2 = 0.0;
    NS_ENDHANDLER
    return (val1 + val2) / 2;
}

- (double)getPixelPerDegreeNoZoom {
    double val1, val2;
    NSRect f;
    NSSize s;
    
    f = [self frame];
    s = [[super image] size];
    NS_DURING
        val1 = (_point[1].x - _point[2].x) * s.width / f.size.width / (_wp[1]._long-_wp[2]._long);
        val2 = (_point[1].y - _point[2].y) * s.width / f.size.width /  (_wp[1]._lat -_wp[2]._lat );
    NS_HANDLER
        val1 = 0.0;
        val2 = 0.0;
    NS_ENDHANDLER
    return (val1 + val2) / 2;
} 

#pragma mark -

- (void) alignPoint {
    NSRect f;
    NSObject *o;
    NSArray *a;
    NetView *n;
    waypoint wp;
    unsigned int i;
    int s = selmode % 3;
    
    if (_point[0].x+_point[0].y>0) {
        f.size=NSMakeSize(40,40);
        f.origin=NSMakePoint(_point[0].x - 20, _point[0].y - 20);
        [self setNeedsDisplayInRect:f];
        [self setNeedsDisplay:YES];
    }
    
    NS_DURING
        _point[0].x = _point[1].x - (_wp[1]._long-_wp[0]._long) / (_wp[1]._long-_wp[2]._long) * (_point[1].x-_point[2].x);
        _point[0].y = _point[1].y - (_wp[1]._lat - _wp[0]._lat) / (_wp[1]._lat - _wp[2]._lat) * (_point[1].y-_point[2].y);
    NS_HANDLER
        _point[0].x = -100;
        _point[0].y = -100;
    NS_ENDHANDLER
    
    if (_point[s].x+_point[s].y>0) {
        f=[_wpView frame];
        f.origin.x=_point[s].x-f.size.width/2;
        f.origin.y=_point[s].y-f.size.height/2;
        [_wpView setFrame:f];
    } else {
        f=[_wpView frame];
        f.origin.x=-100;
        f.origin.y=-100;
        [_wpView setFrame:f];
    }
    
    a = _subviews;
    for (i=0;i<[a count];i++) {
        o=[a objectAtIndex:i];
        if ([o isMemberOfClass:[NetView class]]) {
            n = (NetView*)o;
            f = [n frame];
            wp = [n coord];
            NS_DURING
                f.origin.x = _point[1].x - (_wp[1]._long-wp._long) / (_wp[1]._long-_wp[2]._long) * (_point[1].x - _point[2].x) - 12;
                f.origin.y = _point[1].y - (_wp[1]._lat - wp._lat) / (_wp[1]._lat - _wp[2]._lat) * (_point[1].y - _point[2].y) - (f.size.height)/2 + 5;
            NS_HANDLER
                f.origin.x = -100;
                f.origin.y = -100;
            NS_ENDHANDLER
            [n setFrame:f];
        }
    }
}

- (void) setCurrentPoint:(waypoint) wp {
    _wp[0]=wp;
    [self alignPoint];
}

- (void)setWaypoint:(int)which toPoint:(NSPoint)point atCoordinate:(waypoint)coord {
    int oldmode;
    _point[which] = point;
    _wp[which] = coord;
    
    oldmode = selmode;
    selmode = which;
    [self alignPoint];
    selmode = oldmode;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:KisMACAdvNetViewInvalid object:self];
}

- (void)setVisible:(bool)visible {
    if (visible) {
        [_wpView animate:nil];
        [self alignPoint];
    } else {
        [_wpView stopAnimation:nil];
    }
}

- (void)waitThread:(id)object {
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];

    if([_Lock tryLock]) {
        while(_waitForWaypoint) {
            if (aWPD.done) {
                _waitForWaypoint=NO;
                if (selmode==3) {
                    if (!aWPD.canceled) [[WaveHelper gpsController] setCurrentPointNS: aWPD.w._lat EW: aWPD.w._long ELV: aWPD.w._elevation];
		}
                else if (!aWPD.canceled) _wp[selmode]=aWPD.w;
                else _point[selmode]=_old;
                
                [self alignPoint];
                [[NSNotificationCenter defaultCenter] postNotificationName:KisMACAdvNetViewInvalid object:self];
                [NSApp endModalSession:aMS];
            }
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        [_Lock unlock];
    }
    
    [subpool release];
}

- (void)setImage:(NSImage *)image {
    [self setFrameSize: [image size]];
    [super setImage: image];
    
    [_scrollView setFrame:[_scrollView frame]];
}

- (void)setFrame:(NSRect)frameRect {
    NSRect r=_frame, t=[_parentView frame];
    t.size=frameRect.size;
    [_parentView setFrame:t];
    
    _point[0].x*=frameRect.size.width/r.size.width;
    _point[0].y*=frameRect.size.height/r.size.height;

    _point[1].x*=frameRect.size.width/r.size.width;
    _point[1].y*=frameRect.size.height/r.size.height;

    _point[2].x*=frameRect.size.width/r.size.width;
    _point[2].y*=frameRect.size.height/r.size.height;
    
    [self alignPoint];
    if (_trace) [_trace setFrame:frameRect];
    [_advNetView setFrame:frameRect];
    
    [super setFrame:frameRect];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    NSPoint mouseLoc;
    NSRect redrawRect;
    
    redrawRect.size=NSMakeSize(40,40);
    _old=_point[selmode % 3];
    
    while (keepOn) {
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

        switch ([theEvent type]) {
            case NSLeftMouseUp:
                keepOn = NO;
                if ((selmode!=0)&&(!_waitForWaypoint)) {
                    aWayPoint = [[WayPoint alloc] initWithWindowNibName:@"WayPointDialog"];
                    [[aWayPoint window] setFrameUsingName:@"aKisMAC_WayPoint"];
                    [[aWayPoint window] setFrameAutosaveName:@"aKisMAC_WayPoint"];
                    
                    aWPD.done=NO;
                    if (selmode==3) {
                        // calculate current point for setting the current position
                        NS_DURING
                            aWPD.w._long = _wp[1]._long - (_point[1].x - mouseLoc.x) / (_point[1].x - _point[2].x) * (_wp[1]._long - _wp[2]._long);
                            aWPD.w._lat  = _wp[1]._lat  - (_point[1].y - mouseLoc.y) / (_point[1].y - _point[2].y) * (_wp[1]._lat  - _wp[2]._lat);
                        NS_HANDLER
                            aWPD.w._long = 0.0;
                            aWPD.w._lat  = 0.0;
                        NS_ENDHANDLER
                        _point[0].x = 0;
                    } else // set the waypoints with current coordinates
                        aWPD.w=[[WaveHelper gpsController] currentPoint];
                    
                    _waitForWaypoint=YES;
                    [NSThread detachNewThreadSelector:@selector(waitThread:) toTarget:self withObject:nil];
                    
                    [aWayPoint setCallbackStruct:&aWPD];
                    [aWayPoint showWindow:self];
                    aMS=[NSApp beginModalSessionForWindow:[aWayPoint window]];
                    [NSApp runModalSession:aMS];
                }
            case NSLeftMouseDragged:
                redrawRect.origin=NSMakePoint(mouseLoc.x - 20, mouseLoc.y - 20);
                [self setNeedsDisplayInRect:redrawRect];
                [self setNeedsDisplay:YES];
                
                _point[selmode % 3]=mouseLoc;
                [self setNeedsDisplay:YES];
                break;
            default:
                /* Ignore any other kind of event. */
                break;
        }
    };
    
    return;
}

#pragma mark -

- (IBAction)setWaypoint1:(id)sender {
    if ([sender state] == NSOnState) {
        [sender setState:NSOffState];
        [_wpView setMode:-1];
        selmode=3;
        [self setNeedsDisplay:YES];
        return;
    }
    
    [_wp1 setState:NSOnState];
    [_wp2 setState:NSOffState];
    [_scp setState:NSOffState];
    [_cp setState:NSOffState];
    
    selmode=1;
    [_wpView setMode:selmode];
    
    [self alignPoint];
    [self setNeedsDisplay:YES];
}
- (IBAction)setWaypoint2:(id)sender {
    if ([sender state] == NSOnState) {
        [sender setState:NSOffState];
        [_wpView setMode:-1];
        selmode=3;
        [self setNeedsDisplay:YES];
        return;
    }
    
    [_wp1 setState:NSOffState];
    [_wp2 setState:NSOnState];
    [_scp setState:NSOffState];
    [_cp setState:NSOffState];
    
    selmode=2;
    [_wpView setMode:selmode];
    
    [self alignPoint];
    [self setNeedsDisplay:YES];
}

- (IBAction)setCP:(id)sender {
    if ([sender state] == NSOnState) {
        [sender setState:NSOffState];
        [_wpView setMode:-1];
        selmode=3;
        [self setNeedsDisplay:YES];
        return;
    }
    
    [_wp1 setState:NSOffState];
    [_wp2 setState:NSOffState];
    [_scp setState:NSOnState];
    [_cp setState:NSOffState];
    
    selmode=3;
    [_wpView setMode:0];
    
    [self alignPoint];
    [self setNeedsDisplay:YES];
}
- (IBAction)setNoWayPoint:(id)sender {
    if ([sender state] == NSOnState) {
        [sender setState:NSOffState];
        [_wpView setMode:-1];
        selmode=3;
        [self setNeedsDisplay:YES];
        return;
    }

    [_wp1 setState:NSOffState];
    [_wp2 setState:NSOffState];
    [_scp setState:NSOffState];
    [_cp setState:NSOnState];
    
    selmode=0;
    [_wpView setMode:selmode];
    
    [self alignPoint];
    [self setNeedsDisplay:YES];
}
- (IBAction)showTrace:(id)sender {
    if ([sender state]==NSOffState) {
        _trace = [[TraceView alloc] init];
        [_trace setFrame:_frame];
        [self addSubview:_trace];
        [sender setState:NSOnState];
    } else {
        [_trace removeFromSuperview];
        [_trace release];
        _trace = Nil;
        [sender setState:NSOffState];
    }
}
- (IBAction)resetTrace:(id)sender {
    [[WaveHelper gpsController] resetTrace];
}

- (IBAction)setShowNetworks:(id)sender {
    NSObject *o;
    NSArray *a;
    NetView *n;
    unsigned int i;
    
    if ([sender state]==NSOffState) {
        _showNetworks = YES;
        [sender setState:NSOnState];
    } else {
        _showNetworks = NO;
        [sender setState:NSOffState];
    }
    
    a = _subviews;
    for (i=0;i<[a count];i++) {
        o=[a objectAtIndex:i];
        
        if ([o isMemberOfClass:[NetView class]]) {
            n = (NetView*)o;
            [n setNetVisible:_showNetworks];
        }
    }
    [self setNeedsDisplay:YES];
}

#pragma mark -

- (void)dealloc {
    [_trace release];
    [_advNetView release];
    
    [super dealloc];
}

@end
