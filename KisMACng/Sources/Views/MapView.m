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

@interface MapView(Private)
- (void)_align;
- (void)_setStatus:(NSString*)status;
- (void)_setGPSStatus:(NSString*)status;
@end

@implementation MapView(Private)
- (void)_align {
    NSPoint loc;

    loc.x = (_frame.size.width - [_statusImg size].width)  / 2;
    loc.y = (_frame.size.height- [_statusImg size].height) / 2;
    [_statusView setLocation:loc];
}
- (void)_setStatus:(NSString*)status {
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSSize size;
    NSColor *red = [NSColor colorWithCalibratedRed:.8 green:0 blue:0 alpha:1];
    
    [WaveHelper secureReplace:&_status withObject:status];
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:red forKey:NSForegroundColorAttributeName];
    
    size = [_status sizeWithAttributes:attrs];
    size.width += 20;
    size.height += 10;
    
    [WaveHelper secureReplace:&_statusImg withObject:[[[NSImage alloc] initWithSize:size] autorelease]];
    [_statusImg lockFocus];
    [[red colorWithAlphaComponent:0.1] set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(0,0,size.width,size.height)] fill];
    [red set];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(1,1,size.width-2,size.height-2)] stroke];
    [_status drawAtPoint:NSMakePoint(10,5) withAttributes:attrs];
    [_statusImg unlockFocus];
    
    [_statusView setImage:_statusImg];
    [self _align];
}
- (void)_setGPSStatus:(NSString*)status {
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSColor *grey = [NSColor lightGrayColor];
    
    [WaveHelper secureReplace:&_gpsStatus withObject:status];
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:grey forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *a = [[[NSAttributedString alloc] initWithString:_gpsStatus attributes:attrs] autorelease];
    [_gpsStatusView setString:a];
    [_gpsStatusView setBorderColor:grey];
    [_gpsStatusView setBackgroundColor:[grey colorWithAlphaComponent:0.1]];
}
@end

@implementation MapView

- (void)awakeFromNib {
    [self setBackgroundColor:[NSColor blackColor]];
    
    _statusView = [[BIGLImageView alloc] init];
    [self _setStatus:NSLocalizedString(@"No map loaded! Please import or load one first.", "map view status")];
    [self addSubView:_statusView];
    
    _gpsStatusView = [[BIGLTextView alloc] init];
    [self _setGPSStatus:NSLocalizedString(@"No GPS device available.", "gps status")];
    [self addSubView:_gpsStatusView];
}

#pragma mark -

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self _align];
}
- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self _align];
}

#pragma mark -

- (void)dealloc {
    [_status release];
    [_statusImg release];
    [_statusView release];
    [_gpsStatus release];
    [_gpsStatusView release];
    [_map release];
    
    [super dealloc];
}

@end
