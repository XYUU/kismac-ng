/*
        
        File:			AdvNetView.m
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

#import <BIGeneric/BIValuePair.h>
#import "AdvNetView.h"
#import "WaveHelper.h"
#import "WaveNet.h"
#import "ImportController.h"
//#import "ZoomPictureView.h"

extern NSString *const KisMACAdvNetViewInvalid;

@implementation AdvNetView

-(id) init {
    self=[super init];
    if (self==Nil) return Nil;
    
    _isCached = NO;
    
    return self;
}

- (void)drawRect:(NSRect)rect {
    double w, h, r, g, b, a;
    int    sx, sy, wx, wy, x, y, i;
    NSRect rec;
    
    if (!_isCached) return;
    
    if ([self lockFocusIfCanDraw]) {
        NS_DURING
            w = _frame.size.width  / _width;
            h = _frame.size.height / _height;
    
            sx = (int)floor(rect.origin.x / w);
            sy = (int)floor(rect.origin.y / h);
            wx = sx + (int)ceil(rect.size.width  / w)+1;
            wy = sy + (int)ceil(rect.size.height / h)+1;
            
            rec.size=NSMakeSize(w,h);
            if (wx>_width ) wx = _width;
            if (wy>_height) wy = _height;
            if (sx < 0) sx = 0;
            if (sy < 0) sy = 0;
            
            for (x=sx; x<wx; x++)
                for (y=sy; y<wy; y++) {
                    i = _cache[x][y];
                    if (i==0) continue;
                    
                    a =  (i >> 24) & 0xFF;
                    r =  (i >> 16) & 0xFF;
                    g =  (i >> 8 ) & 0xFF;
                    b =  (i      ) & 0xFF;
        
                    [[NSColor colorWithCalibratedRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a/255.0] set];
                    rec.origin=NSMakePoint(x*w,y*h);
                    [NSBezierPath fillRect:rec];
                }
        NS_HANDLER
            //if an error occurs make this invalid...
            [[NSNotificationCenter defaultCenter] postNotificationName:KisMACAdvNetViewInvalid object:self];
        NS_ENDHANDLER
        [self unlockFocus];
    }
}

- (void)makeCache:(id)object {
    double xx, yy, s, a, d, av, sens, maxd;
    int *c, q, t, nc, i, x, y;
    double **f;
    NSPoint p;
    NSDictionary *coord;
    NSEnumerator *e;
    BIValuePair *v;
    ZoomPictureView *z;
    NSColor *good, *bad, *col;
    double zoom;
    NSSize imgs;
    ImportController *im;
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];
    WaveNet *dwn;
    
    im = [WaveHelper importController];

    if (!_nets) goto exit;

    good = [WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"NetAreaColorGood"]];
    bad  = [WaveHelper intToColor:[[NSUserDefaults standardUserDefaults] objectForKey:@"NetAreaColorBad"]];
    sens = [[[NSUserDefaults standardUserDefaults] objectForKey:@"NetAreaSensitivity"] intValue];
    _qual = (int)(101.0 - sqrt(([[[NSUserDefaults standardUserDefaults] objectForKey:@"NetAreaQuality"] floatValue])*1000.0));
    z = [WaveHelper zoomPictureView];
    zoom = [z getPixelPerDegreeNoZoom];
    imgs = [[z image] size];
    
    if (_isCached) { //delete cache
        for (x = 0; x< _width; x++)
            delete [] _cache[x];
        delete [] _cache;
        _isCached = NO;
    }
    
    _width = (unsigned int)(imgs.width );
    _width = (_width - (_width % _qual)) / _qual +1;
    _height= (unsigned int)(imgs.height);
    _height= (_height- (_height% _qual)) / _qual +1;
    [im setMax:_width];
    _cache = new int* [_width];
    for (x=0; x<_width; x++) {
        _cache[x] = new int[_height];
        for (t=0; t<_height; t++) _cache[x][t]=0;
    }
    _isCached = YES;
    
    nc = [_nets count];
    if (nc==0) {
        [self unlockFocus];
        goto exit;
    }
    
    f = new double* [nc];
    c = new int [nc];
    
    for (t=0;t<nc;t++) {
        dwn = [_nets objectAtIndex:t];
        coord = [dwn coordinates];
        c[t] = [coord count];
        f[t] = new double[c[t]*3];
        q = 0;
    
        e = [coord keyEnumerator];
        while (v = [e nextObject]) {
            [z calcPixelNoZoomforNS:[v getY] EW:[v getX] forPoint:&p];
            f[t][q++] = p.x;
            f[t][q++] = p.y;
            f[t][q++] = [[coord objectForKey:v] intValue];
        }
    }
    
    for (x = 0; x < _width; x++) {
        for (y = 0; y < _height; y++) {
            maxd = 0;
            xx = x * _qual;
            yy = y * _qual;
            
            //IDW algorithm with a decline function
            for (t=0; t<nc; t++) {
                s = 0;
                av = 0;
                for (q=0; q<c[t]; q++) {
                    NS_DURING
                        d = sqrt((xx-f[t][3*q])*(xx-f[t][3*q])+(yy-f[t][3*q+1])*(yy-f[t][3*q+1]));
                        a = 1 / (d * d);
                        av += a;
                        s += a * f[t][3 * q + 2] * (1/d) * (1/30000.0) * (zoom) * sqrt(377.0/(4.0 * 3.1415));
                    NS_HANDLER
                    NS_ENDHANDLER
                }
                if (av>0) { 
                    s/=av;
                    if (s > maxd) maxd = s;
                }
            }
            
            if (maxd>0.1) {
                col = [bad blendedColorWithFraction:(maxd / sens) ofColor:good];
                i  = (unsigned int)floor([col alphaComponent] * 255.0 * (maxd < 1.1 ? (maxd-0.1) : 1.0)) << 24;
                i |= (unsigned int)floor([col redComponent]   * 255) << 16;
                i |= (unsigned int)floor([col greenComponent] * 255) << 8;
                i |= (unsigned int)floor([col blueComponent]  * 255);
                _cache[x][y] = i;
            }  else _cache[x][y] = 0;
        }
        
        [im increment];
        if ([im canceled]) {
            for (x = 0; x< _width; x++)
                delete [] _cache[x];
            delete [] _cache;
            _isCached = NO;
            break;
        }
    }
        
    for(t=0; t<nc; t++) delete [] f[t];
    delete [] f;
    delete [] c;

exit:
    [im terminateWithCode:0];
    [NSApp stopModal];
    [subpool release];
}

- (void) showNetwork:(WaveNet*) net {
    [WaveHelper secureReplace:&_nets withObject:[NSArray arrayWithObject:net]];
    [NSThread detachNewThreadSelector:@selector(makeCache:) toTarget:self withObject:nil];
 }

- (void) showAllNetworks:(NSArray*)nets {
    [WaveHelper secureReplace:&_nets withObject:nets];    
    [NSThread detachNewThreadSelector:@selector(makeCache:) toTarget:self withObject:nil];
}

- (void) clearMap {
    int x;
    [WaveHelper secureRelease:&_nets];
     
    if (_isCached) {
        _isCached = NO;
        for (x=0; x<_width; x++)
            delete [] _cache[x];
        delete [] _cache;
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    [[WaveHelper zoomPictureView] mouseDown:theEvent];
}

- (void)dealloc {
    int x;
    [WaveHelper secureRelease:&_nets];
    
    if (_isCached) {
        _isCached = NO;
        for (x=0; x<_width; x++)
            delete [] _cache[x];
        delete [] _cache;
    }
    [super dealloc];
}

@end
