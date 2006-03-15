/*
        
        File:			MapDownload.m
        Program:		KisMAC
	Author:			Michael Rossberg
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

#import "MapDownload.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <netdb.h>

@implementation MapDownload

+ (MapDownload*)mapDownload {
    return [[[MapDownload alloc] init] autorelease];
}

#pragma mark -

- (NSString*)urlFromExpedia:(NSString*)server language:(NSString*)lang forPoint:(waypoint)w resolution:(NSSize)size zoomLevel:(int)zoom {
    NSString *req, *error;
    int scale;
    float expediaFactorW, expediaFactorH;
    int sockd;
    struct sockaddr_in serv_name;
    char buf[2024];
    int status;
    struct hostent *hp;
    u_long ip;
    int bytesread;
    NSString *s;
    int errcount = 0;
    CFHTTPMessageRef myMessage;
    
    scale = 6 - zoom;
    /*
    req = [NSString stringWithFormat:@"http://%@/pub/agent.dll?qscr=mrdt&CenP=%f,%f&Lang=%@&Alti=%d&MapS=0&Size=%d,%d&Offs=0.000000,0", 
        server, w._lat, w._long, lang, scale, (int)size.width, (int)size.height];
    
    NSDictionary *dic;
    NSHTTPCookieStorage *cookiestore;
    NSHTTPCookie *cookie;
    
    NS_DURING
        cookiestore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        if (cookiestore) {
            if ([cookiestore cookieAcceptPolicy]==NSHTTPCookieAcceptPolicyNever) {
                NSLog(@"Error: Cookies disabled!");
                NSBeginAlertSheet(@"Cookies disabled.",nil,nil,nil,[self window],nil,nil,nil,nil,
                @"The Expedia server requires cookies to be enabled! Since KisMAC uses the same sub-system as Safari, you will need to open it and enable cookies. \
You can also select another server, which does not require cookies. You can also select the \"accept cookies from the site you navigate to\" option \
in Safari.");
                NS_VOIDRETURN;
            }
            dic = [NSDictionary dictionaryWithObjectsAndKeys:@"http://www.expedia.com/", NSHTTPCookieOriginURL, @"jscript", NSHTTPCookieName, @"1", NSHTTPCookieValue, nil];
            cookie = [NSHTTPCookie cookieWithProperties:dic];
            if (cookie) [cookiestore setCookie:cookie];
            else NSLog(@"Critical Error: Could not create cookie!");
        } else {
            NSLog(@"Error: Cookie Storage unavailable. Operating System needs to be 10.2.6 with Safari 1.0 intalled!");
            NSBeginAlertSheet(@"Invalid Operating System.",nil,nil,nil,[self window],nil,nil,nil,nil,
            @"The Expedia server requires a complete browser system in order to send maps. KisMAC can provide this, however you will need at least a MacOS X 10.2.6 installation, with Safari 1.0 or higher installed!");
            NS_VOIDRETURN;
        }
    NS_HANDLER
        NSLog(@"Error: Cookie Storage unavailable. Operating System needs to be 10.2.6 with Safari 1.0 intalled!");
        NSBeginAlertSheet(@"Invalid Operating System.",nil,nil,nil,[self window],nil,nil,nil,nil,
        @"The Expedia server requires a complete browser system in order to send maps. KisMAC can provide this, however you will need at least a MacOS X 10.2.6 installation, with Safari 1.0 or higher installed!");
        return;
    NS_ENDHANDLER*/
                
    sockd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockd == -1) {
        error = @"Socket creation failed!";
        goto err;
    }
    
    hp = gethostbyname([server cString]);
    if (hp == NULL) {
        error = NSLocalizedString(@"Could not resolve expedia server", "Download Map Error");;
        goto err;
    }
    ip = *(int *)hp->h_addr_list[0];

    /* server address */ 
    serv_name.sin_family = AF_INET;
    serv_name.sin_addr.s_addr = ip;
    serv_name.sin_port = htons(80);
    
    NSLog(@"Connecting to expedia (%s, %x)",inet_ntoa(serv_name.sin_addr), ip);
    
    /* connect to the server */
    status = connect(sockd, (struct sockaddr*)&serv_name, sizeof(serv_name));
    if (status == -1) {
        error = NSLocalizedString(@"Could not connect to www.expedia.com", "Download Map Error");;
        goto err;
    }
        
    s = [NSString stringWithFormat:@"GET /pub/agent.dll?qscr=mrdt&CenP=%f,%f&Lang=%@&Alti=%d&MapS=0&Size=%d,%d&Offs=0.000000,0 HTTP/1.0\nHost: %@\nCookie: jscript=1\nConnection: close\n\n", 
        w._lat, w._long, lang, scale, (int)size.width, (int)size.height, server];

    NSLog(@"Sending request to expedia");
    write(sockd, [s cString], [s length]);
    s = [NSString string];
    
    NSLog(@"Reading response from expedia");
    
    bytesread = read(sockd, buf, 2024);
    while ((bytesread != -1) && ([s length] < 1100)) {
        if (bytesread==0) {
            errcount++;
            if (errcount == 60) {
                error = NSLocalizedString(@"Got no response from expedia. Mapsize too big?", "Download Map Error");
                goto err;
            }
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        } else {
            errcount = 0;
            s = [s stringByAppendingString:[NSString stringWithCString:buf length:bytesread]];
        }
        bytesread = read(sockd, buf, 2024);
    }
    close(sockd);

    //NSLog(@"Response from expedia %@",s);
    
    myMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);
    if (!CFHTTPMessageAppendBytes(myMessage, (UInt8*)[s cString], [s length])) {
        error = @"CFTTPResponse Parsing error";
        close(sockd);
        goto err;
    }
    
    if (!CFHTTPMessageIsHeaderComplete(myMessage)) {
        error = @"Incomplete Headers!";
        goto err;
    }
    
    req = (NSString*)CFHTTPMessageCopyHeaderFieldValue(myMessage, CFSTR("Location"));
    NSLog(@"New location is at %@", req);
        
    switch(scale) {
        case 5:
            expediaFactorH = 15900;
            expediaFactorW = 16030.76934;
            break;
        case 4:
            expediaFactorH = 19900;
            expediaFactorW = 19953.19163;
            break;
        case 3:
            expediaFactorH = 26500;
            expediaFactorW = 26433.71541;
            break;
        case 2:
            expediaFactorH = 39800;
            expediaFactorW = 39703.79291;
            break;
        case 1:
            expediaFactorH = 79600;
            expediaFactorW = 79812.76652;
            break;
        default:
            expediaFactorH = 1;
            expediaFactorW = 1;
            NSLog(@"Warning Invalid Zoom Size!");
            NSBeep();
    }
    
    if (expediaFactorW) {
        expediaFactorH *= 2; //for the half map only
        expediaFactorW *= 2; //for the half map only
        
        _p1.x = size.width;
        _p1.y = size.height;
        _p2 = NSZeroPoint;
        _w1._lat  = w._lat  + size.height / expediaFactorH;
        _w1._long = w._long + size.width / (expediaFactorW * cos(_w1._lat * 0.017453292)); //the width depends on latitude
        _w2._lat  = w._lat  - size.height / expediaFactorH;
        _w2._long = w._long - size.width / (expediaFactorW  * cos(_w2._lat * 0.017453292)); //the width depends on latitude
    }
    
    return req;
    
err:
    close(sockd);
    return nil;
}

- (BOOL)downloadMapFrom:(NSString*)server forPoint:(waypoint)w resolution:(NSSize)size zoomLevel:(int)zoom {
    NSString *req;
    int scale;
    float scalef;
    
    if ((int)size.width == 0) { size.width = 1000; }
    if ((int)size.height == 0) { size.height = 1000; }
    if (zoom == 0) { zoom = 3; }
    
    if (!server) return NO;
    if ((int)size.height < 0 || (int)size.width < 0 || (int)size.height > 10000 || (int)size.width > 10000) return NO;
    if (w._lat > 90 || w._lat < -90 || w._long < -180 || w._long > 180) return NO;
    if (zoom > 5 || zoom < 1) return NO;
    
    _p1.x = size.width / 2.0;
    _p1.y = size.height / 2.0;
    _w1 = w;
    _p2.x = 0;
    _p2.y = 0;
    _w2._lat  = 0;
    _w2._long = 0;

    if ([server isEqualToString:@"TerraServer (Satellite)"]) {
        scale = 16 - zoom;
        req = [NSString stringWithFormat:@"http://terraserver-usa.com/GetImageArea.ashx?t=1&s=%d&lon=%f&lat=%f&w=%d&h=%d", scale, w._long, w._lat, (int)size.width, (int)size.height];
    } else if ([server isEqualToString:@"TerraServer (Map)"]) {
        scale = 16 - zoom;
        req = [NSString stringWithFormat:@"http://terraserver-usa.com/GetImageArea.ashx?t=2&s=%d&lon=%f&lat=%f&w=%d&h=%d", scale, w._long, w._lat, (int)size.width, (int)size.height];
    } else if ([server isEqualToString:@"Expedia (United States)"]) {
        req = [self urlFromExpedia:@"www.expedia.com" language:@"0409USA" forPoint:w resolution:size zoomLevel:zoom];
    } else if ([server isEqualToString:@"Expedia (Europe)"]) {
        req = [self urlFromExpedia:@"www.expedia.de" language:@"EUR0407" forPoint:w resolution:size zoomLevel:zoom];
    } else if ([server isEqualToString:@"Map24"]) {
        size = NSMakeSize(1000,1000);
        req = [NSString stringWithFormat:@"http://maptp.map24.com/map24/cgi?locid0=tmplocid0&wx0=%f&wy0=%f&iw=%d&ih=%d&mid=MAP24", w._long * 60.0, w._lat * 60.0, (int)size.width, (int)size.height];    
  
        _p1.x = size.width;
        _p1.y = size.height;
        _p2 = NSZeroPoint;
        
        //0.017453292 is for degree to rad conversion
        _w1._lat  = w._lat  + size.height / (1040.0 * 2 * 60.0 * cos(w._lat  * 0.017453292));
        _w1._long = w._long + size.width  / (712.0  * 2 * 60.0 * cos(_w1._lat * 0.017453292)); //the width depends on latitude
        _w2._lat  = w._lat  - size.height / (1040.0 * 2 * 60.0 * cos(w._lat  * 0.017453292));
        _w2._long = w._long - size.width  / (712.0  * 2 * 60.0 * cos(_w2._lat * 0.017453292)); //the width depends on latitude
    } else if ([server isEqualToString:@"Census Bureau Maps (United States)"]) {
        scalef = zoom;
        
        req = [NSString stringWithFormat:@"http://tiger.census.gov/cgi-bin/mapper/map.gif?&lat=%f&lon=%f&ht=%f&wid=%f&conf=mapnew.con&iht=%d&iwd=%d",
            w._lat, w._long, 0.065/scalef, 0.180/scalef, (int)size.height, (int)size.width];
    } else {
        NSLog(@"Invalid server!");
        return NO;
    }

    NSLog(@"Try to load map from the following location: %@", req);
    
    [_img autorelease];
    _img = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:req]];

    NSLog(@"Map loaded");
    return _img != nil;
}

#pragma mark -

- (NSPoint)waypoint1Pixel {
    return _p1;
}

- (waypoint)waypoint1 {
    return _w1;
}

- (NSPoint)waypoint2Pixel {
    return _p2;
}

- (waypoint)waypoint2 {
    return _w2;
}

- (NSImage*)map {
    return _img;
}

#pragma mark -

- (void)dealloc {
    [_img release];
	[super dealloc];
}

@end
