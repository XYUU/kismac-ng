/*
        
        File:			WayPointView.m
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

#import "WayPointView.h"
#import "WaveHelper.h"

@implementation WayPointView

- (void) setupViewForFrame:(NSRect) frame {
    float r1=1, r2=10, x1, y1;
    NSAffineTransform *t;

    [_way1 autorelease];
    _way1=[NSBezierPath bezierPath];
    
    x1=cos(30.0/180.0*pi)*r1;
    y1=sin(30.0/180.0*pi)*r1;
    
    [_way1 moveToPoint:NSMakePoint(x1,y1)];
    [_way1 lineToPoint:NSMakePoint(x1+cos(60.0/180.0*pi)*r2,y1+sin(60.0/180.0*pi)*r2)];
    [_way1 lineToPoint:NSMakePoint(x1+cos(0.0/180.0*pi)*r2 ,y1+sin(0.0/180.0*pi)*r2) ];
    [_way1 closePath];
    
    x1=cos(150.0/180.0*pi)*r1;
    y1=sin(150.0/180.0*pi)*r1;
    
    [_way1 moveToPoint:NSMakePoint(x1,y1)];
    [_way1 lineToPoint:NSMakePoint(x1+cos(120.0/180.0*pi)*r2,y1+sin(120.0/180.0*pi)*r2)];
    [_way1 lineToPoint:NSMakePoint(x1+cos(180.0/180.0*pi)*r2,y1+sin(180.0/180.0*pi)*r2) ];
    [_way1 closePath];
    
    x1=cos(270.0/180.0*pi)*r1;
    y1=sin(270.0/180.0*pi)*r1;
    
    [_way1 moveToPoint:NSMakePoint(x1,y1)];
    [_way1 lineToPoint:NSMakePoint(x1+cos(240.0/180.0*pi)*r2,y1+sin(240.0/180.0*pi)*r2)];
    [_way1 lineToPoint:NSMakePoint(x1+cos(300.0/180.0*pi)*r2,y1+sin(300.0/180.0*pi)*r2) ];
    [_way1 closePath];
    
    t = [NSAffineTransform transform];
    [t translateXBy:0.5*frame.size.width yBy:0.5*frame.size.height];
    [_way1 transformUsingAffineTransform: t];

    [_way1 retain];
}

- (id)initWithFrame:(NSRect)frame { 
    self = [super initWithFrame:frame];
    if (self) {
        _animLock = [[NSLock alloc] init];
        _shallAnimate = NO;
        _mode = 0;
        [self setupViewForFrame:frame];
    }    
    return self;
}

#pragma mark -

- (void)drawRect:(NSRect)rect {
    static int scale = 35;
    static bool e;
    
    if (_mode==0) {    
        NSRect q;
        NSColor *c = [WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"CurrentPositionColor"]];
        NSBezierPath *x;
        float z;
        int w;
        
        if (scale<8) w=scale/2;
        else w=4;
        
        if (e) {
            scale++;
            if (scale>=25) e=NO;
        } else {
            scale--;
            if (scale<=10) e=YES;
        }
                
        q.size.height=q.size.width=scale;
        
        q.origin.x=(_frame.size.width -scale)/2;
        q.origin.y=(_frame.size.height-scale)/2;
        
        for (z=w;z>=-w;z--) {
            [[c blendedColorWithFraction:(((float)abs(z))/w) ofColor:[NSColor clearColor]] set];
            x=[NSBezierPath bezierPathWithOvalInRect:q];
            [x setLineWidth:1.5];
            [x stroke];
            q.origin.x++;
            q.origin.y++;
            q.size.height-=2;
            q.size.width-=2;
        }

    } else if (_mode > 0) {
        [[WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"WayPointColor"]] set];
    
        NSAffineTransform *t4 = [NSAffineTransform transform];
        [t4 translateXBy:-_frame.size.width*0.5 yBy:-_frame.size.height*0.5];
        //[_way1 transformUsingAffineTransform: t4];
        
        t4 = [NSAffineTransform transform];
        [t4 rotateByDegrees: 5];
        [t4 translateXBy:-_frame.size.width*0.5 yBy:-_frame.size.height*0.5];
        [_way1 transformUsingAffineTransform: t4];
        
        t4 = [NSAffineTransform transform];
        [t4 translateXBy:_frame.size.width*0.5 yBy:_frame.size.height*0.5];
        [_way1 transformUsingAffineTransform: t4];
        
        [_way1 fill];
    }
}


- (void)setFrame:(NSRect)frameRect {
    NSSize r = _frame.size;
    if (memcmp(&frameRect.size,&r,sizeof(r)))
        [self setupViewForFrame:frameRect];
    [super setFrame:frameRect];
}

- (void)mouseDown:(NSEvent *)theEvent {
    [[WaveHelper zoomPictureView] mouseDown:theEvent];
}

#pragma mark -

- (void)setMode:(int)mode {
    _mode = mode;
}

- (IBAction)animate:(id)sender {
    _shallAnimate = YES;
    [NSThread detachNewThreadSelector:@selector(animThread:) toTarget:self withObject:nil];
}

- (IBAction)stopAnimation:(id)sender {
    _shallAnimate = NO;
}

- (void)animThread:(id)object {
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];

    if([_animLock tryLock]) {
        while(_shallAnimate) {
            if (_mode > 0) [self displayRectIgnoringOpacity:_frame];
            //[self setNeedsDisplay:YES];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow: (_mode ? 0.0375 : 0.1)]];
        }
        [_animLock unlock];
    }
    
    [subpool release];
}

#pragma mark -

- (void)dealloc {
    [_animLock release];
}
@end
