/*
        
        File:			CustomScrollView.m
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

#import "CustomScrollView.h"
#import "WaveHelper.h"

@implementation CustomScrollView

- (NSSize)validateContentSize:(NSSize)content forView:(NSSize) x {
    NSSize f = [NSScrollView contentSizeForFrameSize:content hasHorizontalScroller:YES hasVerticalScroller: YES borderType: NSBezelBorder];
    NSSize r = x;
    float fx, fy;
    
    if ((r.height<=f.height)&&(r.width<=f.width)) {
        fx = r.height / f.height;
        fy = r.width  / f.width;
        
        if (fy<fx) {
            r.height/=fx;
            r.width /=fx;
        } else {
            r.height/=fy;
            r.width /=fy;
        }
        
        [_smaller setEnabled:NO];
    }
    
    return r;
}

- (void)setFrame:(NSRect)frameRect {
    NSRect r = [_view frame];
    
    r.size = [self validateContentSize:frameRect.size forView: r.size];
    
    [_view setFrame:r];
    [super setFrame:frameRect];
}

- (IBAction)bigger:(id)sender {
    NSPoint p;
    NSRect cf;
    NSRect r = [_view frame];
    float x, y;
    r.size.width*=2;
    r.size.height*=2;
    cf = [_contentView frame];
    
    x = [_hScroller floatValue];
    y = [_vScroller floatValue];
    p.x = x * (r.size.width - cf.size.width);
    p.y = (1.0 - y) * (r.size.height - cf.size.height);
    
    [_smaller setEnabled:YES];
    [_view setFrame:r];
    [_view setNeedsDisplay:YES];
    //p=[[WaveHelper zoomPictureView] currentPosition];
    
    if (p.x >= 0 && p.y >= 0 && p.x <= r.size.width && p.y <= r.size.height) {
        p.x = p.x + cf.size.width / 4;
        p.y = p.y + cf.size.height / 4;
        
        if (p.x > (r.size.width - cf.size.width)) p.x = r.size.width - cf.size.width;
        if (p.x < 0) p.x = 0;
        
        if (p.y > (r.size.height - cf.size.height)) p.y = r.size.height - cf.size.height;
        if (p.y < 0) p.y = 0;
        
        [self scrollClipView:_contentView toPoint:p];
        [self reflectScrolledClipView:_contentView];
    }
}

- (IBAction)smaller:(id)sender {
    NSPoint p;
    NSRect cf;
    NSRect r = [_view frame];
    float x,y;
    cf = [_contentView frame];
    
    r.size.width/=2;
    r.size.height/=2;
    
    r.size = [self validateContentSize:_frame.size forView: r.size];

    x = [_hScroller floatValue];
    y = [_vScroller floatValue];
    p.x = x * (r.size.width - cf.size.width);
    p.y = (1.0 - y) * (r.size.height - cf.size.height);
    
    [_view setFrame:r];
    [_view setNeedsDisplay:YES];
    [self setNeedsDisplay:YES];

    //p=[[WaveHelper zoomPictureView] currentPosition];
    if (p.x >= 0 && p.y >= 0 && p.x <= r.size.width && p.y <= r.size.height) {
        p.x = p.x - cf.size.width / 8;
        p.y = p.y - cf.size.height / 8;
        
        if (p.x > (r.size.width - cf.size.width)) p.x = r.size.width - cf.size.width;
        if (p.x < 0) p.x = 0;
        
        if (p.y > (r.size.height - cf.size.height)) p.y = r.size.height - cf.size.height;
        if (p.y < 0) p.y = 0;
        
        [self scrollClipView:_contentView toPoint:p];
        [self reflectScrolledClipView:_contentView];
    }
}

@end
