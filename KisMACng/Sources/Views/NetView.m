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
#import "MapView.h"
#import "WaveNet.h"
#import "WaveHelper.h"

#define USE_FAST_IMAGE_VIEWS

@implementation NetView

- (id)initWithNetwork:(WaveNet*)network {
    self = [super init];
    if (self) {
        _name = [[NSString stringWithString:@"<no ssid>"] retain];
        _netImg = [[NSImage imageNamed:@"NetworkUnkEnc.tif"] retain];
        _netColor = [[NSColor yellowColor] retain];
        _wep = 0;
        _wp._lat = 0;
        _wp._long = 0;
	_wp._elevation = 0;
        _network = network;
        _registered = NO;
    }
    return self;
}

- (void) setName:(NSString*)name {
    [WaveHelper secureReplace:&_name withObject:name];
    [self setImage:[self generateImage]];
    [[WaveHelper mapView] setNeedsDisplay:YES];
}

- (void) setWep:(encryptionType)wep {
    _wep = wep;

    [WaveHelper secureRelease:&_netImg];
    [WaveHelper secureRelease:&_netColor];
    
    switch (_wep) {
    case encryptionTypeUnknown:
        _netImg = [[NSImage imageNamed:@"NetworkUnkEnc.tif"] retain];
        _netColor = [[NSColor yellowColor] retain];
        break;
    case encryptionTypeNone:
        _netImg = [[NSImage imageNamed:@"NetworkNoEnc.tif"] retain];
        _netColor = [[NSColor greenColor] retain];
        break;
    case encryptionTypeWEP:
    case encryptionTypeWEP40:
        _netImg = [[NSImage imageNamed:@"NetworkWEP.tif"] retain];
        _netColor = [[NSColor redColor] retain];
        break;
    case encryptionTypeWPA:
        _netImg = [[NSImage imageNamed:@"NetworkWPA.tif"] retain];
        _netColor = [[NSColor blueColor] retain];
        break;
    case encryptionTypeLEAP:
        _netImg = [[NSImage imageNamed:@"NetworkLEAP.tif"] retain];
        _netColor = [[NSColor cyanColor] retain];
        break;
    default:
        _netImg = [[NSImage imageNamed:@"NetworkStrange.tif"] retain];
        _netColor = [[NSColor magentaColor] retain];
    }
    
    [self setImage:[self generateImage]];
    [[WaveHelper mapView] setNeedsDisplay:YES];
}

-(void) setCoord:(waypoint)wp {
    _wp = wp;
    [self align];
}

- (waypoint)coord {
    return _wp;
}

#pragma mark -

- (void)mouseDown:(NSEvent *)theEvent {
    if ([theEvent clickCount] == 2) [_network joinNetwork];
    else [[WaveHelper mapView] mouseDown:theEvent];
}

- (void)align {
    NSPoint p;
    p = [[WaveHelper mapView] pixelForCoordinate:_wp];

    if (!_visible || (p.x == INVALIDPOINT.x && p.y == INVALIDPOINT.y)) {
        if (_registered) [[WaveHelper mapView] removeNetView:self];
        return;
    }
        
    if (!_registered) {
        [[WaveHelper mapView] addNetView:self];
    }
    
    [self setLocation:p];
}

- (void)setLocation:(NSPoint)loc {
    [super setLocation:NSMakePoint(loc.x - 7.5, loc.y - ([_img size].height / 2))];
}

- (NSImage*)generateImage {
    float r = 15;
    NSBezierPath *legendPath = [NSBezierPath bezierPath];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    NSString *name;
    NSSize size = NSZeroSize;
    NSImage *img;
        
    if (!_visible) return [[[NSImage alloc] initWithSize:NSMakeSize(0,0)] autorelease];
    
    name =[_name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; 
    if ([name length] > 0) {
        [attrs setObject:textFont forKey:NSFontAttributeName];
        
        size = [_name sizeWithAttributes:attrs];
        size.height+=5;
        size.width+=10;
    }
    
    float height = fmax(r, size.height);
    img = [[NSImage alloc] initWithSize:NSMakeSize(size.width + r + 10, height)];
    [img lockFocus];
    
    if ([name length]) {
        [legendPath appendBezierPathWithRect:NSMakeRect(r+5, (height - size.height)/2, size.width, size.height)];
        [[[NSColor blackColor] colorWithAlphaComponent:0.75] set];
        [legendPath fill];
        [[[NSColor whiteColor] colorWithAlphaComponent:0.3] set];
        [NSBezierPath setDefaultLineWidth:2];
        [legendPath stroke];
        
        [attrs setObject:_netColor forKey:NSForegroundColorAttributeName];
        [_name drawAtPoint:NSMakePoint(r+10, (height + 5 - size.height)/2) withAttributes:attrs];
    }
   
    [_netImg dissolveToPoint:NSMakePoint(0, (height - r)/2) fraction:1.0];
    
    [img unlockFocus];
    
    return [img autorelease];
}

- (void)dealloc {
    if (_registered) [[WaveHelper mapView] removeNetView:self];
    
    [[WaveHelper mapView] setNeedsDisplay:YES];
    [WaveHelper secureRelease:&_name];
    [WaveHelper secureRelease:&_network];
    [WaveHelper secureRelease:&_netImg];
    [WaveHelper secureRelease:&_netColor];
    
    [super dealloc];
}
@end
