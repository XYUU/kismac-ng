/*

        File:			NetView.m
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

#import "NetView.h"
#import "WaveNet.h"
#import "WaveHelper.h"

#define USE_FAST_IMAGE_VIEWS

@implementation NetView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _name = [[NSString stringWithString:@"<no ssid>"] retain];
        _img = [[NSImage imageNamed:@"NetworkUnkEnc.tif"] retain];
        _netColor = [[NSColor yellowColor] retain];
        _wep = 0;
        _wp._lat = 0;
        _wp._long = 0;
	_wp._elevation = 0;
        _visible = YES;
        _network = nil;
        //TODO
        //[[WaveHelper mapView] addSubview:self];
        //[[WaveHelper mapView] alignPoint];
    }
    return self;
}

- (void)setNetwork:(id)network {
    [WaveHelper secureReplace:&_network withObject:network];
}

-(void) setNetVisible:(bool)visible {
    _visible = visible;
}

- (void) setName:(NSString*)name {
    [WaveHelper secureReplace:&_name withObject:name];
    [self setNeedsDisplay:YES];
}

- (void) setWep:(encryptionType)wep {
    _wep = wep;

    [WaveHelper secureRelease:&_img];
    [WaveHelper secureRelease:&_netColor];
    
    switch (_wep) {
    case encryptionTypeUnknown:
        _img = [[NSImage imageNamed:@"NetworkUnkEnc.tif"] retain];
        _netColor = [[NSColor yellowColor] retain];
        break;
    case encryptionTypeNone:
        _img = [[NSImage imageNamed:@"NetworkNoEnc.tif"] retain];
        _netColor = [[NSColor greenColor] retain];
        break;
    case encryptionTypeWEP:
    case encryptionTypeWEP40:
        _img = [[NSImage imageNamed:@"NetworkWEP.tif"] retain];
        _netColor = [[NSColor redColor] retain];
        break;
    case encryptionTypeWPA:
        _img = [[NSImage imageNamed:@"NetworkWPA.tif"] retain];
        _netColor = [[NSColor blueColor] retain];
        break;
    case encryptionTypeLEAP:
        _img = [[NSImage imageNamed:@"NetworkLEAP.tif"] retain];
        _netColor = [[NSColor cyanColor] retain];
        break;
    default:
        _img = [[NSImage imageNamed:@"NetworkStrange.tif"] retain];
        _netColor = [[NSColor magentaColor] retain];
    }
    
    [self setNeedsDisplay:YES];
}

-(void) setCoord:(waypoint)wp {
    _wp = wp;
    //[[WaveHelper mapView] alignPoint];
}

-(waypoint) coord {
    return _wp;
}

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([theEvent clickCount] == 2) [_network joinNetwork];
    else [[WaveHelper zoomPictureView] mouseDown:theEvent];
}

- (void)drawRect:(NSRect)rect {
#ifndef USE_FAST_IMAGE_VIEWS
    NSRect q;
    float z;
    NSBezierPath *x;
#endif
    float r = 14;
    NSBezierPath *legendPath = [[NSBezierPath alloc] init];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    
    if (!_visible) return;
    
    if ([[_name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] > 0) {
        NSSize size;
        [attrs setObject:textFont forKey:NSFontAttributeName];
        
        size = [_name sizeWithAttributes:attrs];
        size.height+=5;
        size.width+=10;
        
        [legendPath appendBezierPathWithRect:NSMakeRect(r+10, (_frame.size.height - 10 - size.height)/2, size.width, size.height)];
        [[[NSColor blackColor] colorWithAlphaComponent:0.75] set];
        [legendPath fill];
        [[[NSColor whiteColor] colorWithAlphaComponent:0.3] set];
        [NSBezierPath setDefaultLineWidth:2];
        [legendPath stroke];
        [legendPath release];
    
        [attrs setObject:_netColor forKey:NSForegroundColorAttributeName];
        [_name drawAtPoint:NSMakePoint(r+15, (_frame.size.height - 5 - size.height)/2) withAttributes:attrs];
    }
   
#ifdef USE_FAST_IMAGE_VIEWS
    [_img dissolveToPoint:NSMakePoint(0,0) fraction:1.0];
#else
    q.size.height=q.size.width=r;
    
    q.origin.x=(5);
    q.origin.y=(_frame.size.height - 10 - r)/2;
    
    for (z=(r/2-1);z>=0;z--) {
        [[_netColor blendedColorWithFraction:(z/(r/2-1)) ofColor:[NSColor blackColor]] set];
        x=[NSBezierPath bezierPathWithOvalInRect:q];
        [x setLineWidth:1.5];
        [x stroke];
        q.origin.x++;
        q.origin.y++;
        q.size.height-=2;
        q.size.width-=2;
    }
#endif

}

-(void) dealloc {
    [[WaveHelper mapView] setNeedsDisplay:YES];
    [WaveHelper secureRelease:&_name];
    [WaveHelper secureRelease:&_network];
    [WaveHelper secureRelease:&_img];
    [WaveHelper secureRelease:&_netColor];
}
@end
